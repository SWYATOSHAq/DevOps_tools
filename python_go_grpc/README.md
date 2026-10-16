# Практическая работа 4 — Python, Go, gRPC и mTLS

Linux-окружение Ubuntu 24.04 работает в Docker на macOS. В одном учебном
контейнере запущены Go-сервер, nginx и три независимых Django-процесса.

## Запуск

Из этой папки:

```sh
docker compose up --build -d
docker compose exec lab python manage.py check
docker compose exec lab go test ./server/...
docker compose exec lab python -m scripts.verify
```

Открыть http://127.0.0.1:8000 (дополнительные клиенты: 8001 и 8002).
Кнопка «Бросить кубики» вызывает оба маршрута. `/grpc` и `/nginx` возвращают JSON.

```sh
docker compose logs lab
docker compose down
```

## Маршруты

- Django → mTLS → Go, `127.0.0.1:8443`.
- Django → mTLS → nginx, `127.0.0.1:9448` → h2c → Go, `127.0.0.1:50051`.
- Незащищённый h2c-порт доступен только внутри контейнера на loopback.
- HTTP-порты публикуются только на loopback компьютера.

Протокол `proto/api.proto` задаёт `DiceService.RollDie`; ответ — целое число 1–6.
CFSSL при запуске создаёт локальный CA, серверный и клиентский сертификаты.
На сервере включено `RequireAndVerifyClientCert`, в nginx — `ssl_verify_client on`.
Ключи генерируются внутри контейнера и не входят в Git или Docker-образ.
Это учебный запуск с Django runserver, не production-развёртывание.

## Структура

- `client/` — Django, gRPC-клиент и шаблон страницы.
- `server/` — Go-сервер, interceptor логирования и тест параллельных запросов.
- `proto/` — единый контракт Protocol Buffers.
- `certs/` — только JSON-параметры CA и сертификатов.
- `scripts/generate.sh` — генерация Python/Go из proto.
- `scripts/start.sh` — сертификаты, проверки, запуск процессов и их остановка.
- `scripts/verify.py` — интеграционная проверка обоих маршрутов и отказа без сертификата.

## Исправления примера методички

Единый nginx-порт 9448 вместо несовпадающих 9445/9448; корректный Go module и
`go_package`; относительный импорт Python после генерации; HTML-шаблон в
исходниках, а не в site-packages; отдельные обработчики `/grpc` и `/nginx`;
тайм-аут RPC и HTTP 502 при ошибке вместо неопределённой переменной; синхронизация
генератора случайных чисел; порт Django задаётся позиционным аргументом
`runserver 0.0.0.0:8001`, без несуществующего `-p`. В контейнере процессы
запускаются напрямую, без systemctl и без изменения настроек macOS.

## Документация

- https://grpc.io/docs/languages/python/quickstart/
- https://nginx.org/en/docs/http/ngx_http_grpc_module.html
- https://docs.djangoproject.com/en/5.2/ref/django-admin/#runserver
