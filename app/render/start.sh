#!/bin/bash
# Boots the whole ERPNext app tier in one container:
#   redis (cache + queue), gunicorn, socket.io, worker, scheduler, nginx.
# Site files live on the Render disk mounted at /home/frappe/frappe-bench/sites.
set -euo pipefail
cd /home/frappe/frappe-bench

SITE="${SITE_NAME:-frontend}"
DB_PORT="${DB_PORT:-3306}"
: "${DB_HOST:?DB_HOST is not set}"
: "${DB_ROOT_PASSWORD:?DB_ROOT_PASSWORD is not set}"
: "${ADMIN_PASSWORD:?ADMIN_PASSWORD is not set}"

# Render SSH sessions may not inherit service env vars; keep a private copy
# for restore-site.sh (container filesystem only, not the disk).
umask 077
cat > /home/frappe/render/.env <<EOF
export SITE_NAME='${SITE}'
export DB_ROOT_PASSWORD='${DB_ROOT_PASSWORD}'
export ADMIN_PASSWORD='${ADMIN_PASSWORD}'
EOF
umask 0002

echo "==> Starting Redis (cache :13000, queue :11000)"
redis-server --port 13000 --bind 127.0.0.1 --save "" --appendonly no \
  --maxmemory 256mb --maxmemory-policy allkeys-lru --daemonize yes \
  --logfile /tmp/redis-cache.log --dir /tmp
redis-server --port 11000 --bind 127.0.0.1 --save "" --appendonly no \
  --daemonize yes --logfile /tmp/redis-queue.log --dir /tmp

echo "==> Writing common_site_config.json"
ls -1 apps > sites/apps.txt
[ -f sites/common_site_config.json ] || echo '{}' > sites/common_site_config.json
jq --arg db "$DB_HOST" --argjson port "$DB_PORT" --arg site "$SITE" '. + {
  db_host: $db, db_port: $port, default_site: $site,
  redis_cache: "redis://127.0.0.1:13000",
  redis_queue: "redis://127.0.0.1:11000",
  redis_socketio: "redis://127.0.0.1:11000",
  socketio_port: 9000, server_script_enabled: 1
}' sites/common_site_config.json > /tmp/csc.json
cp /tmp/csc.json sites/common_site_config.json

echo "==> Waiting for MariaDB at ${DB_HOST}:${DB_PORT}"
wait-for-it -t 600 "${DB_HOST}:${DB_PORT}"

if [ ! -f "sites/${SITE}/site_config.json" ]; then
  echo "==> First boot: creating site '${SITE}' (takes a few minutes)"
  # Placeholder page so Render sees the port open while ERPNext installs.
  python3 -m http.server 8080 --directory /home/frappe/render/setup-page &
  PLACEHOLDER=$!
  rm -rf "sites/${SITE}"
  bench new-site "$SITE" \
    --mariadb-user-host-login-scope='%' \
    --db-root-username root --db-root-password "$DB_ROOT_PASSWORD" \
    --admin-password "$ADMIN_PASSWORD" \
    --install-app erpnext --set-default
  kill "$PLACEHOLDER" || true
  wait "$PLACEHOLDER" 2>/dev/null || true
fi

# Run migrations once per image version (e.g. after bumping the ERPNext tag).
VERSION="$(grep -h '^__version__' apps/frappe/frappe/__init__.py apps/erpnext/erpnext/__init__.py | tr -d '\n')"
if [ "$(cat sites/.render_version 2>/dev/null || true)" != "$VERSION" ]; then
  echo "==> New app version detected, running migrate"
  bench --site "$SITE" migrate
  echo "$VERSION" > sites/.render_version
fi

if [ -n "${RENDER_EXTERNAL_URL:-}" ]; then
  bench --site "$SITE" set-config host_name "$RENDER_EXTERNAL_URL"
fi

echo "==> Starting ERPNext processes"
export BACKEND=127.0.0.1:8000 SOCKETIO=127.0.0.1:9000 NGINX_LISTEN_PORT=8080
export FRAPPE_SITE_NAME_HEADER="$SITE"
exec honcho -f /home/frappe/render/Procfile -d /home/frappe/frappe-bench start
