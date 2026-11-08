#!/usr/bin/env bash
# Back up the whole stack (app data + .env) to ~/backups on the iMac.
# Run on the iMac from anywhere:  ~/projects/homelab-stack/scripts/backup.sh
# Paperless documents in Docker volumes are NOT in ./data — export those from
# inside Paperless (guide, "Backups"). Everything else lives here.
set -euo pipefail
STACK_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$HOME/backups"
mkdir -p "$OUT_DIR"
STAMP="$(date +%F)"
# Stop containers briefly so SQLite DBs (ntfy, Vaultwarden) copy cleanly.
cd "$STACK_DIR"
docker compose stop >/dev/null 2>&1 || true
tar --exclude='sync' -czf "$OUT_DIR/homelab-stack-$STAMP.tar.gz" -C "$STACK_DIR" data homepage .env docker-compose.yml
docker compose start >/dev/null 2>&1 || true
echo "Backup written: $OUT_DIR/homelab-stack-$STAMP.tar.gz"
echo "Note: ./sync is excluded (it exists on your other machines by design)."
