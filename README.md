# DevOps_tools

![DevOps_tools](./DevOps_tools-social-preview.jpg)

## Порядок разработки

Изменения выполняются в отдельных ветках от `dev` и поступают в неё через
pull request. GitHub Actions проверяет локальные изображения в README и
запускает тесты при push в `dev` и при pull request с целевой веткой `dev`.
После проверки результат может переноситься в `main`.

Локальная проверка:

```sh
python3 tools/check_repository.py
python3 -m unittest discover -s tests -v
```

## Практическая работа №4

[Python и Go через gRPC, mTLS и nginx](python_go_grpc/README.md).
Запуск Linux-окружения: `cd python_go_grpc && docker compose up --build -d`.
