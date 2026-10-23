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

echo "Пройдено: $PASS, не пройдено: $FAIL"
[[ "$FAIL" -eq 0 ]]
