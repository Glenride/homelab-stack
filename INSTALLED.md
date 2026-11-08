# Tier 1 core stack — INSTALLED 2026-10-22

Installed by Janine over SSH at D'Vaughn's tap ("Install the core stack for me now").
Location on the iMac: `~/projects/homelab-stack` (user `housedv`, host `homelab`).

## Running (core, all verified HTTP 200/302 on localhost, LAN and tailnet)
| App | LAN | Tailnet |
|---|---|---|
| Homepage | http://192.168.1.191:3000 | http://100.81.149.115:3000 |
| ntfy | http://192.168.1.191:8086 | http://100.81.149.115:8086 |
| Healthchecks | http://192.168.1.191:8008 | http://100.81.149.115:8008 |
| changedetection.io | http://192.168.1.191:5000 | http://100.81.149.115:5000 |
| Vaultwarden | http://192.168.1.191:8081 | http://100.81.149.115:8081 |
| Syncthing | http://192.168.1.191:8384 | http://100.81.149.115:8384 |

Ports remapped from defaults for this machine: ntfy 8086 (8080 = ThinkTank OS web), Healthchecks 8008 (8000 = D'Quizz). Profiles (docs / tools / network) are NOT started.

## Done during install
- `.env` generated on the iMac by setup.sh (secrets stay there, chmod 600). PUID/PGID 1000.
- Homepage allowed hosts include LAN IP, tailnet IP, and `homelab` (fixed after a 400 on the tailnet address).
- ntfy: users `dvaughn` (admin) and `alerts` (write-only on topic `homelab`) created; passwords appended to `.env` as `NTFY_DVAUGHN_PASSWORD` / `NTFY_ALERTS_PASSWORD`. End-to-end test passed: published as `alerts`, read back as `dvaughn` (message id kfKtBK98pvrs).
- Healthchecks: 4 checks created (plus the app's default "My First Check"):
  - mission-control-morning-sweep — cron `36 9 * * *` America/New_York, grace 2h — ping code 718e2bf6-2b2a-4ea8-ab29-8c9b094032d5
  - mission-control-evening-sweep — cron `36 18 * * *`, grace 2h — ping code ee6fcadf-422c-444c-8ef6-358addeb874e
  - drug-shortage-digest-monday — every 7 days, grace 12h — ping code eda1fbe7-f5d4-4670-858b-1dad40a2478b
  - job-scraper-weekday — cron `30 8 * * MON-FRI`, grace 6h — ping code 6ac52a14-c4e4-4604-9a34-c9185c411ebc
  - Ping base: `http://100.81.149.115:8008/ping/<code>` (tailnet form — the form external jobs must use; LAN form works inside the house).

## Still his (personal steps, given to him 2026-10-22)
1. iPhone: install ntfy app, add server, log in as `dvaughn` (password in `.env`), subscribe to topic `homelab`.
2. Healthchecks UI: add the ntfy integration (Integrations → ntfy) so missed checks buzz his phone; change the superuser password (initial one in `.env`).
3. Vaultwarden: create his account at :8081, then Janine flips `VW_SIGNUPS_ALLOWED=false` on request (or he runs the guide's sed).
4. Syncthing: set GUI password; pair the Mac Studio (accept on the Studio side).
5. changedetection: set an admin password; add watches; set notification URL with the `alerts` credentials.

## Not yet wired
- The Healthchecks ping URLs are created but NOT yet added to the Mission Control / digest / job-scraper crons — that's the follow-on wiring step.
- AdGuard profile: port 53 is already listening on the iMac (unidentified in preflight) — resolve before `--profile network`.
