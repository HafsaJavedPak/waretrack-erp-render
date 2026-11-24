#!/bin/bash
# Restores a site backup tarball made by push-data.sh, then resets the
# Administrator password to the ADMIN_PASSWORD set on Render.
# Usage: restore-site.sh /home/frappe/frappe-bench/sites/upload/backup.tar
set -euo pipefail
cd /home/frappe/frappe-bench
[ -f /home/frappe/render/.env ] && source /home/frappe/render/.env
SITE="${SITE_NAME:-frontend}"
TAR="${1:?path to backup tar}"

WORK="$(mktemp -d -p sites .restore.XXXX)"
trap 'rm -rf "$WORK"' EXIT
tar -xf "$TAR" -C "$WORK"
DB="$(ls "$WORK"/*-database.sql.gz | head -1)"
PUB="$(ls "$WORK"/*-files.tar 2>/dev/null | grep -v private-files | head -1 || true)"
PRIV="$(ls "$WORK"/*-private-files.tar 2>/dev/null | head -1 || true)"
CONF="$(ls "$WORK"/*-site_config_backup.json | head -1)"

echo "==> Restoring $(basename "$DB") into site $SITE"
bench --site "$SITE" set-maintenance-mode on
bench --site "$SITE" restore "$DB" \
  --db-root-username root --db-root-password "$DB_ROOT_PASSWORD" \
  ${PUB:+--with-public-files "$PUB"} ${PRIV:+--with-private-files "$PRIV"}

# Keep the original encryption key so saved passwords (email, APIs) still decrypt.
KEY="$(jq -r '.encryption_key // empty' "$CONF")"
[ -n "$KEY" ] && bench --site "$SITE" set-config encryption_key "$KEY"

bench --site "$SITE" set-admin-password "$ADMIN_PASSWORD"
bench --site "$SITE" migrate
bench --site "$SITE" enable-scheduler
bench --site "$SITE" set-maintenance-mode off
bench --site "$SITE" clear-cache
rm -f "$TAR"
# Reload gunicorn workers so nothing serves stale in-memory state.
# (no pkill/pgrep in this image, so walk /proc)
for d in /proc/[0-9]*; do
  cmd="$(tr '\0' ' ' < "$d/cmdline" 2>/dev/null || true)"
  [[ "$cmd" == *gunicorn*frappe.app* ]] && kill -HUP "${d#/proc/}" 2>/dev/null || true
done
echo "==> Restore complete."
