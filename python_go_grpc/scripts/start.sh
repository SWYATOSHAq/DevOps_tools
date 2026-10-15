#!/usr/bin/env bash
set -euo pipefail
cd /app
bash certs.sh
python manage.py check
nginx -t -p /app/ -c nginx.conf
pids=()
cleanup() { kill "${pids[@]}" 2>/dev/null || true; wait || true; }
trap cleanup EXIT
trap 'exit 0' TERM INT
dice-server & pids+=("$!")
nginx -p /app/ -c nginx.conf -g 'daemon off;' & pids+=("$!")
for port in 8000 8001 8002; do
 python manage.py runserver "0.0.0.0:$port" --noreload & pids+=("$!")
done
wait -n "${pids[@]}"
