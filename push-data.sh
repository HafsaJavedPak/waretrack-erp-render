#!/bin/bash
# Copies your LOCAL ERPNext site (everything you configured in the UI, plus
# uploaded files) to the Render deployment, replacing what is there.
#
# Usage:  ./push-data.sh srv-xxxxxxxxxxxx@ssh.singapore.render.com
# (copy the address from Render dashboard -> waretrack-erp -> Connect -> SSH)
set -euo pipefail

REMOTE="${1:?Usage: ./push-data.sh <render-ssh-address>}"
HERE="$(cd "$(dirname "$0")" && pwd)"
COMPOSE="docker compose -f ${HERE}/../frappe_docker/pwd.yml"
SITE=frontend
STAMP="$(date +%Y%m%d-%H%M%S)"
TMP_IN=/tmp/render-push-${STAMP}
LOCAL_TAR="$(mktemp -d)/backup-${STAMP}.tar"
REMOTE_DIR=/home/frappe/frappe-bench/sites/upload

echo "==> 1/4 Backing up local site '${SITE}' (database + files)"
$COMPOSE exec -T backend bash -c "
  set -e
  bench --site ${SITE} backup --with-files --backup-path ${TMP_IN} >/dev/null
  cd ${TMP_IN} && tar -cf /tmp/backup-${STAMP}.tar . && rm -rf ${TMP_IN}"
$COMPOSE cp "backend:/tmp/backup-${STAMP}.tar" "$LOCAL_TAR"
$COMPOSE exec -T backend rm -f "/tmp/backup-${STAMP}.tar"
echo "    $(du -h "$LOCAL_TAR" | cut -f1) backup ready"

echo "==> 2/4 Preparing upload folder on Render"
ssh -o StrictHostKeyChecking=accept-new "$REMOTE" "mkdir -p ${REMOTE_DIR}"

echo "==> 3/4 Uploading"
if ! scp -s "$LOCAL_TAR" "${REMOTE}:${REMOTE_DIR}/backup.tar"; then
  echo "    scp failed, retrying over plain ssh"
  ssh "$REMOTE" "cat > ${REMOTE_DIR}/backup.tar" < "$LOCAL_TAR"
fi

echo "==> 4/4 Restoring on Render (a few minutes)"
ssh "$REMOTE" "/home/frappe/render/restore-site.sh ${REMOTE_DIR}/backup.tar"

rm -rf "$(dirname "$LOCAL_TAR")"
echo "Done. Log in as Administrator with the ADMIN_PASSWORD shown in Render"
echo "(waretrack-erp -> Environment). Your other users keep their local passwords."
