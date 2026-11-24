# WareTrack ERPNext on Render

ERPNext v16.53.0 (same image as local `frappe_docker/pwd.yml`) as a Render Blueprint.

| Service | What | Plan | Disk |
|---|---|---|---|
| `waretrack-erp` (web) | gunicorn, socket.io, worker, scheduler, redis, nginx | 1c-2g | 5 GB `sites` |
| `waretrack-db` (private) | MariaDB 11.8 | 0.5c-512mb | 10 GB |

Render snapshots both disks daily (kept 7 days).

## Deploy (once)
1. Render dashboard → **New → Blueprint** → pick this repo → **Apply**.
2. Wait ~10 min for the first build and the ERPNext install (open the URL; a "being installed" page shows until done).
3. Administrator password: `waretrack-erp` → **Environment** → `ADMIN_PASSWORD`.

## Copy your local site to Render
1. Add `~/.ssh/id_ed25519.pub` in Render → **Account Settings → SSH Public Keys**.
2. Copy the SSH address from `waretrack-erp` → **Connect → SSH**.
3. With local Docker running: `./push-data.sh srv-xxxx@ssh.singapore.render.com`

This replaces the Render site with your local one. Administrator gets the Render password; other users keep theirs.

## Upgrade ERPNext
Change the tag in `app/Dockerfile`, then push. Migrations run on boot automatically.
