#!/usr/bin/env bash
# Update images and restart the CORE stack.
# Run on the iMac:  ~/projects/homelab-stack/scripts/update.sh
# Profile services (docs/tools/network) are pulled too, but NOT started by
# this script — if you run any of them, apply their update afterwards with:
#   docker compose --profile docs up -d      (or tools / network)
set -euo pipefail
cd "$(dirname "$0")/.."
docker compose --profile docs --profile tools --profile network pull
docker compose up -d
docker image prune -f
docker compose ps
echo ""
echo "Core stack updated. If you run profile services, re-up them now, e.g.:"
echo "  docker compose --profile docs --profile tools up -d"
