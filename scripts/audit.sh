#!/usr/bin/env bash
set -uo pipefail
export LC_ALL=C

PASS=0
FAIL=0

check() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$actual" == "$expected" ]]; then
        echo "[OK] $desc"
        ((PASS+=1))
    else
        echo "[FAIL] $desc (ожидалось: $expected; получено: $actual)"
        ((FAIL+=1))
    fi
}

sudo -v || exit 1
SSH_CONFIG=$(sudo /usr/sbin/sshd -T) || exit 1
UFW_STATUS=$(sudo ufw status verbose) || exit 1

ssh_value() {
    awk -v key="$1" '$1 == key {print $2}' <<< "$SSH_CONFIG"
}

echo "Аудит: $(hostname -f), $(date '+%Y-%m-%d %H:%M')"

echo "[1] Служба SSH"
check "Вход root запрещён" no "$(ssh_value permitrootlogin)"
check "Парольная аутентификация отключена" no \
    "$(ssh_value passwordauthentication)"

PORT=$(ssh_value port)
NONSTANDARD=no
if [[ "$PORT" =~ ^[0-9]+$ ]] && ((PORT >= 1 && PORT <= 65535 && PORT != 22)); then
    NONSTANDARD=yes
fi
check "Порт SSH отличается от 22" yes "$NONSTANDARD"
check "MaxAuthTries равен 3" 3 "$(ssh_value maxauthtries)"

echo "[2] Межсетевой экран"
check "UFW активен" active \
    "$(awk '/^Status:/ {print $2}' <<< "$UFW_STATUS")"
check "Входящий трафик по умолчанию запрещён" deny \
    "$(awk '/^Default:/ {print $2}' <<< "$UFW_STATUS")"

echo "[3] Учётные записи"
awk -F: '$3>=1000 && $3<65534 {
    printf "  %s (uid=%s)\n", $1, $3
}' /etc/passwd

echo "[4] Веб-сервер"
check "Nginx активен" active "$(systemctl is-active nginx)"

nginx_status=0
sudo nginx -t || nginx_status=$?
check "Конфигурация Nginx корректна" 0 "$nginx_status"

cert_min_validity=${CERT_MIN_VALIDITY_SECONDS:-2592000}
cert_status=0
if [[ "$cert_min_validity" =~ ^[0-9]+$ ]]; then
    openssl x509 -in /etc/ssl/certs/devops.crt -noout \
        -checkend "$cert_min_validity" || cert_status=$?
else
    cert_status="некорректный порог"
fi
check "Сертификат действителен ещё $cert_min_validity с" 0 "$cert_status"

if writable_paths=$(sudo find /var/www/devops-site -perm -o+w -print) &&
    key_mode=$(sudo stat -c '%a' /etc/ssl/private/devops.key); then
    permissions_result="${key_mode}${writable_paths:+, запись для всех: $writable_paths}"
else
    permissions_result="не удалось проверить права"
fi
check "Ключ имеет права 600, в каталоге нет записи для всех" 600 "$permissions_result"

echo "Пройдено: $PASS, не пройдено: $FAIL"
[[ "$FAIL" -eq 0 ]]
