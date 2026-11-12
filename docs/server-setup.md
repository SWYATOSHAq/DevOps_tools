# Конфигурация виртуальной машины devops-vm

## 1. Параметры машины

- Среда: Multipass на macOS, архитектура ARM64.
- ОС: Ubuntu 24.04.5 LTS.
- Процессоры: 2.
- Оперативная память: 2 ГиБ.
- Диск: 25 ГиБ.

Multipass использован вместо VirtualBox. Сетевая схема отличается
от указанной в методичке схемы NAT + Host-only.

## 2. Сетевые интерфейсы

- Интерфейс Ubuntu: enp0s1.
- IPv4: 192.168.252.2/24, получен через DHCP.
- Шлюз: 192.168.252.1.
- Назначение: связь с Mac и выход во внешнюю сеть через сеть Multipass.
- Имя сервера: devops-vm.devops.local.

В /etc/hosts Ubuntu:
127.0.1.1 devops-vm.devops.local devops-vm

В /etc/hosts Mac:
192.168.252.2 devops.local

При изменении DHCP-адреса необходимо обновить настройки клиента.

## 3. Правило проброса портов

Проброс портов не настроен: Mac подключается непосредственно
к адресу VM 192.168.252.2, TCP-порт 2222.
Отдельного порта хостовой системы для перенаправления нет.

## 4. Учётные записи

- ubuntu: исходная учётная запись Multipass, UID 1000.
- devops: рабочая учётная запись, UID 1001.
- Группы devops: devops, sudo, users.
- SSH-аутентификация devops: ключ ED25519.
- Приватный ключ хранится на Mac: ~/.ssh/devops_vm.
- Публичный ключ на сервере: /home/devops/.ssh/authorized_keys.
- Владелец каталога и файла: devops.
- Права ~/.ssh: 700; authorized_keys: 600.
- Повышение привилегий: sudo с паролем пользователя devops.

## 5. Служба SSH

Файл: /etc/ssh/sshd_config.d/00-pr5-hardening.conf

Параметры:
Port 2222
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
PermitEmptyPasswords no
MaxAuthTries 3
LoginGraceTime 30
AllowUsers devops
X11Forwarding no
ClientAliveInterval 300
ClientAliveCountMax 2

ssh.socket отключён; ssh.service включён в автозапуск.
Старый процесс, слушавший порт 22, завершён.
Проверено прослушивание только порта 2222.

Конфигурация клиента Mac в ~/.ssh/config:
Host devops
    HostName 192.168.252.2
    User devops
    Port 2222
    IdentityFile ~/.ssh/devops_vm
    IdentitiesOnly yes

Подключение: ssh devops
Подключение по имени: ssh -o HostName=devops.local devops

После изменения SSH-параметров сначала выполнить sudo sshd -t.
Текущую сессию сохранять до проверки нового подключения.

Стандартный доступ Multipass через ubuntu и порт 22 после
усиления настроек SSH недоступен; использовать ssh devops.

## 6. Правила межсетевого экрана

UFW активен и включён при загрузке.

- Входящий трафик по умолчанию: deny.
- Исходящий трафик по умолчанию: allow.
- 2222/tcp: LIMIT IN.
- 80/tcp: ALLOW IN.
- 443/tcp: ALLOW IN.
- Правила созданы для IPv4 и IPv6.

Новое подключение по SSH после включения UFW проверено.

## 7. Снимки состояния

- clean-install: исходная система до создания devops.
- keys-configured: пользователь, sudo и SSH-ключ настроены.
- ssh-hardened: ограничения SSH, UFW, имя сервера и скрипт аудита;
  создан после восстановления MaxAuthTries 3 и успешного аудита.

Снимки созданы при остановленной VM.
Проверка списка: multipass list --snapshots

## 8. Веб-сервер

На 12 ноября 2026 года на Ubuntu установлен пакет `nginx`
версии `1.24.0-2ubuntu7.19`.
`/etc/nginx/sites-enabled/devops-site` указывает на
`/etc/nginx/sites-available/devops-site`. Для `devops.local` порт 80
возвращает 301 на HTTPS, а порт 443 поддерживает TLS 1.2 и TLS 1.3.
HTTPS-блок отдаёт `index.html` и использует `404.html` для ответа 404.
Его журналы находятся в `/var/log/nginx/devops-site.access.log`
и `/var/log/nginx/devops-site.error.log`.

| Путь | Владелец | Права |
|---|---|---|
| `/var/www/devops-site` | `devops:devops` | `755` |
| `/etc/ssl/certs/devops.crt` | `root:root` | `644` |
| `/etc/ssl/private/devops.key` | `root:root` | `600` |

Сертификат содержит SAN `DNS:devops.local` и действует с 5 ноября 2026
по 5 ноября 2027, 15:29:19 UTC. Команда выпуска самоподписанного
сертификата на 365 дней при первичной настройке:

```bash
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/devops.key \
  -out /etc/ssl/certs/devops.crt \
  -subj '/CN=devops.local' -addext 'subjectAltName=DNS:devops.local'
sudo chmod 600 /etc/ssl/private/devops.key
sudo chmod 644 /etc/ssl/certs/devops.crt
sudo nginx -t
```

После выпуска нового сертификата перезагрузить конфигурацию Nginx
и обновить публичный сертификат `~/devops.crt` на Mac для проверки
`curl --cacert ~/devops.crt -I https://devops.local/`.

Аудит дополнительно проверяет состояние Nginx, синтаксис его конфигурации,
запас срока сертификата (30 дней), права ключа и отсутствие объектов с
правом записи для всех. Для отрицательной проверки срока можно задать
`CERT_MIN_VALIDITY_SECONDS=63072000` на один запуск.

## 9. Проверки

Скрипт: scripts/audit.sh.
Запускается внутри Ubuntu.

Проверяет запрет root, запрет парольной аутентификации,
нестандартный SSH-порт, MaxAuthTries 3, активность UFW
и политику deny для входящего трафика.

Результаты аудита практики №5:
- Корректная конфигурация: 6 OK, 0 FAIL, код 0.
- MaxAuthTries временно установлен в 10: 5 OK, 1 FAIL, код 1.
- После восстановления значения 3: 6 OK, 0 FAIL, код 0.

Во время отрицательной проверки SSH не перезапускался:
sshd -T считывает конфигурацию с диска.

Вход root и попытка входа по паролю отклонены.
Вход devops по ключу и подключение через devops.local успешны.

## 10. Восстановление конфигурации после отката clean-install

Инструкция предназначена для будущего восстановления.
Откат удаляет изменения VM после снимка. Перед ним сохранить
нужные файлы на Mac и убедиться в наличии снимка ssh-hardened.

### 10.1 Откат и подготовка пользователя

В работающей Ubuntu выключить машину:
```bash
sudo poweroff
```

На Mac после перехода VM в состояние Stopped:
```bash
multipass restore devops-vm.clean-install
multipass start devops-vm
multipass transfer ~/.ssh/devops_vm.pub devops-vm:/home/ubuntu/devops_vm.pub
multipass transfer scripts/audit.sh devops-vm:/home/ubuntu/audit.sh
multipass shell devops-vm
```

Команды transfer выполнять из корня репозитория на Mac.
Используется существующий ключ; приватный ключ на VM не переносить.
Если адрес VM изменился, обновить ~/.ssh/config и /etc/hosts на Mac.

В Ubuntu под пользователем ubuntu:
```bash
sudo adduser devops
sudo usermod -aG sudo devops
sudo install -d -m 700 -o devops -g devops /home/devops/.ssh
sudo install -m 600 -o devops -g devops /home/ubuntu/devops_vm.pub /home/devops/.ssh/authorized_keys
sudo install -d -m 755 -o devops -g devops /home/devops/scripts
sudo install -m 755 -o devops -g devops /home/ubuntu/audit.sh /home/devops/scripts/audit.sh
```

Задать пароль devops интерактивно; в документации пароль не хранить.

До изменения SSH проверить вход с Mac на исходный порт:
```bash
ssh -p 22 -o PreferredAuthentications=publickey devops
```

В новой сессии проверить:
```bash
whoami
sudo whoami
```

### 10.2 Имя сервера и SSH

В Ubuntu:
```bash
sudo hostnamectl set-hostname devops-vm.devops.local
sudo nano /etc/hosts
```

Строка:
```text
127.0.1.1 devops-vm.devops.local devops-vm
```

Создать /etc/ssh/sshd_config.d/00-pr5-hardening.conf
с полным содержимым из раздела 5.

Проверить синтаксис:
```bash
sudo sshd -t
```

При отсутствии ошибок:
```bash
sudo systemctl disable --now ssh.socket
sudo systemctl daemon-reload
sudo systemctl enable ssh.service
sudo systemctl restart ssh.service
sudo ss -tlnp | grep -E ':(22|2222)[[:space:]]'
```

С Mac открыть отдельное подключение:
```bash
ssh -p 2222 devops
```

В нём проверить:
```bash
echo "$SSH_CONNECTION"
```

Последнее поле должно быть 2222.
Если остался старый listener на 22, определить его актуальный
PID через ss, убедиться, что это старый sshd, и завершить только
этот процесс командой sudo kill -TERM PID.
Не использовать PID из старых скриншотов.

### 10.3 UFW и итоговая проверка

В Ubuntu:
```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw limit 2222/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
sudo ufw status verbose
~/scripts/audit.sh
echo "Код возврата: $?"
```

Аудит практики №5 ожидает 6 успешных проверок и код 0.
Для текущего аудита также нужна настройка веб-сервера по разделу 8.

Не закрывая текущую сессию, с Mac проверить новое подключение:
```bash
ssh devops
```

На Mac должна сохраняться запись в /etc/hosts:
```text
192.168.252.2 devops.local
```

Проверить подключение по имени:
```bash
ssh -o HostName=devops.local devops
```

При появлении запроса доверия сравнить отпечаток ключа сервера
с выводом в доверенной сессии Ubuntu:
```bash
sudo ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
```

Инструкция восстановления составлена по выполненным действиям.
Полный повторный откат и восстановление по ней пока не проводились.

## 9. Контейнеризация

Docker Engine 29.9.3 и Docker Compose 5.7.1 установлены на Ubuntu VM
из официального APT-репозитория Docker. Пользователь `devops` входит
в группу `docker` и запускает контейнеры без `sudo`.

Проект Compose находится в `/home/devops/app`. Файл `.env` создаётся
на VM, имеет права `600` и содержит пароль PostgreSQL. Шаблон переменных
хранится в `app/.env.example`.

Flask и PostgreSQL работают в сети `app_backend`. Приложение обращается
к PostgreSQL по имени `db`. Порт Flask опубликован только на
`127.0.0.1:5000`, порт PostgreSQL на VM не опубликован.
Данные PostgreSQL хранятся в именованном томе `app_db_data`.

В HTTPS-блоке `/etc/nginx/sites-available/devops-site` маршрут `/app/`
проксируется на `http://127.0.0.1:5000/`. Завершающий `/` в `proxy_pass`
убирает префикс `/app/` при передаче запроса. Статическая страница
обслуживается по `/`. После изменения конфигурации выполни
`sudo nginx -t && sudo systemctl reload nginx`.

На этой VM базовый образ Python и образ PostgreSQL были переданы с Mac
через `docker save` и `docker load` из-за тайм-аута Docker Hub. После
тайм-аута PyPI зависимости были скачаны на Mac для Linux ARM64 и
переданы на VM в `~/pr7-wheels` для локальной установки при сборке.
Готовые образы запускаются из `~/app` командой
`docker compose up -d --no-build --pull never --wait`.
