#!/usr/bin/env bash
set -euo pipefail

die() {
    echo "Ошибка: $*" >&2
    exit 1
}

DRY_RUN=false
case "${1:-}" in
    "") ;;
    --dry-run) DRY_RUN=true ;;
    *) die "Использование: deploy.sh [--dry-run]" ;;
esac
[[ $# -le 1 ]] || die "Слишком много аргументов"

ROOT=$(git rev-parse --show-toplevel) ||
    die "Запускайте скрипт внутри репозитория"

REMOTE=devops
REMOTE_DIR=/var/www/devops-site/
SITE_URL=https://devops.local/
CA_CERT="${HOME}/devops.crt"

[[ -f "$ROOT/site/index.html" ]] ||
    die "Отсутствует site/index.html"

CHANGES=$(git -C "$ROOT" status --porcelain) ||
    die "Не удалось проверить состояние Git"

[[ -z "$CHANGES" ]] ||
    die "Есть незакоммиченные изменения"

COMMIT=$(git -C "$ROOT" rev-parse --short HEAD)

OPTIONS=(-avz --delete --chmod=D755,F644)
if "$DRY_RUN"; then
    OPTIONS+=(--dry-run)
else
    [[ -r "$CA_CERT" ]] ||
        die "Недоступен сертификат $CA_CERT"
fi

if ! rsync "${OPTIONS[@]}" \
    -e "ssh -o BatchMode=yes -o ConnectTimeout=5" \
    "$ROOT/site/" "$REMOTE:$REMOTE_DIR"; then
    die "Синхронизация не выполнена"
fi

if "$DRY_RUN"; then
    echo "План развёртывания коммита $COMMIT показан"
    exit 0
fi

if ! curl --fail --silent --show-error \
    --connect-timeout 5 --max-time 20 \
    --cacert "$CA_CERT" \
    --output /dev/null "$SITE_URL"; then
    die "После синхронизации сайт недоступен по HTTPS"
fi

echo "Успешно развёрнут коммит $COMMIT"
