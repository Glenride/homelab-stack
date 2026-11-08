# Homelab Tier 1 starter stack — install guide (iMac)

Everything from the awesome-selfhosted shortlist's Tier 1, in one folder, one command to start. Written click-by-click for the iMac (Arch / Omarchy, user `housedv`). **Nothing here is exposed to the internet** — every app is reachable on your home network and over Tailscale only. Do not port-forward any of these ports on your router.

## What you get

**Core — starts together:**

| App | Address (after setup) | Job |
|---|---|---|
| Homepage | `http://<iMac-IP>:3000` | Front door for the whole lab |
| ntfy | `http://<iMac-IP>:8086` | Push alerts to your phone |
| Healthchecks | `http://<iMac-IP>:8008` | Alerts you when a scheduled job *doesn't* run |
| changedetection.io | `http://<iMac-IP>:5000` | Alerts you when a watched page changes |
| Vaultwarden | `http://<iMac-IP>:8081` | Your password vault |
| Syncthing | `http://<iMac-IP>:8384` | File sync between your machines |

**Profiles — start later, only when you want them:**

| Profile | Apps | Start command |
|---|---|---|
| `docs` | Paperless-ngx (`:8001`) | `docker compose --profile docs up -d` |
| `tools` | Stirling-PDF (`:8082`), Karakeep (`:3001`) | `docker compose --profile tools up -d` |
| `network` | AdGuard Home (`:3002`, DNS on `:53`) | `docker compose --profile network up -d` |

---

## Step 1 — Get the folder onto the iMac

Unzip the package into your projects folder. In a terminal on the iMac:

```bash
mkdir -p ~/projects
cd ~/projects
unzip ~/Downloads/homelab-tier1-stack.zip
mv homelab-tier1-stack homelab-stack
cd ~/projects/homelab-stack
ls
```

You should see: `docker-compose.yml`, `setup.sh`, `README.md`, `homepage/`, `scripts/`, `.env.example`.

## Step 2 — Check Docker is alive

```bash
docker --version && docker compose version
docker run --rm hello-world
```

Both version lines print and hello-world runs (you verified Docker back on Oct 7 — this just re-confirms it). If `docker` says permission denied, you're missing the docker group in *this* shell — log out and back in, or re-run: `sudo usermod -aG docker $USER` and log in again.

## Step 3 — Run setup (creates folders, secrets, and your IP config)

```bash
cd ~/projects/homelab-stack
chmod +x setup.sh scripts/*.sh
./setup.sh
```

- It detects the iMac's LAN IP automatically. If your iMac has several (Wi-Fi + Ethernet) and it picks the wrong one, run `./setup.sh 192.168.1.191` with the right IP instead (use your real one — `hostname -I` shows the candidates).
- It writes `.env` with **fresh random secrets generated on the iMac**. First-login passwords live in that file too. It's chmod 600 — never send it anywhere, never commit it.
- It refuses to overwrite an existing `.env`, so re-running is safe.

## Step 4 — Start the core stack

```bash
docker compose pull
docker compose up -d
docker compose ps
```

First pull downloads ~6 images; give it a few minutes. `docker compose ps` should list homepage, ntfy, healthchecks, changedetection, vaultwarden, syncthing — all `running` (healthchecks can take ~30 seconds to settle).

Open **http://\<iMac-IP\>:3000** — that's Homepage, with a card for every app. Click through each card once to confirm it loads. If one doesn't, check its logs: `docker compose logs <name> --tail=50`.

## Step 5 — ntfy: your alert pipe (10 minutes, do this first)

The stack starts locked down (`deny-all`), so create two users — one for you, one for your services to publish with. The commands prompt you to type a password for each; pick passwords you'll store in Vaultwarden in Step 7.

```bash
docker exec -it ntfy ntfy user add --role=admin dvaughn
docker exec -it ntfy ntfy user add alerts
docker exec -it ntfy ntfy access dvaughn homelab read-write
docker exec -it ntfy ntfy access alerts  homelab write-only
```

Test it from the iMac terminal (use the `alerts` password):

```bash
curl -u alerts -d "Homelab alerts are alive" http://localhost:8086/homelab
```
(It asks for the password, then returns a JSON message — that's success.)

On your **iPhone**: install the free **ntfy** app → add your server (`http://<iMac-IP>:8086`, or the iMac's Tailscale address when you're away from home) → log in as `dvaughn` → subscribe to the topic **homelab**. The stack already sets `NTFY_UPSTREAM_BASE_URL=https://ntfy.sh`, which is what makes iOS notifications arrive instantly instead of on a delay — that's the documented requirement for self-hosted ntfy on iPhone.

From now on, anything can reach your phone with one line, e.g. from any script on the iMac:
`curl -u alerts:PASSWORD -d "message" http://<iMac-IP>:8086/homelab`

## Step 6 — Healthchecks: watch the watchers

1. Open `http://<iMac-IP>:8008` and log in: email `dvaughnhouse@gmail.com`, password = the `HC_SUPERUSER_PASSWORD` value in `.env` (see it with `grep HC_SUPERUSER .env` while in the stack folder). Change the password inside the app afterwards.
2. **Integrations → ntfy:** server `http://ntfy`, topic `homelab`, and the `alerts` user credentials from Step 5. Send the test alert — your phone should buzz.
   *(Why `http://ntfy` works: the containers talk to each other by name on the stack's own network. Your browser/phone always uses the iMac-IP addresses.)*
3. Create these checks (name → how often it should ping → grace period):
   - `mission-control-morning-sweep` → every 12 hours → grace 2 hours
   - `mission-control-evening-sweep` → every 12 hours → grace 2 hours
   - `drug-shortage-digest` → every 7 days → grace 12 hours
   - `job-scraper-weekday` → every 1 day → grace 6 hours
4. Each check gives you a **ping URL**. Any job proves it's alive with one line at its end:
   `curl -fsS -m 10 --retry 3 https://<ping-URL>` — the crons that run on Janine's side can be wired to these URLs; just hand the ping URLs back in chat when you're ready and that wiring happens then. A job that *fails* can ping `<ping-URL>/fail` instead.

## Step 7 — changedetection.io: three watches to start

1. Open `http://<iMac-IP>:5000`. Set an admin password (Settings → Password) right away.
2. Settings → Notifications → Notification URL, paste this (with the `alerts` password from Step 5):
   `ntfy://alerts:PASSWORD@ntfy/homelab`
   Send a test — phone buzzes.
3. Add your first three watches (any page URL, check daily):
   - The FDA drug-shortages page (feeds the Glenride Monday digest)
   - A grant-program page you track for the chain-grants watch
   - Oscilar's careers page

## Step 8 — Vaultwarden: your vault

1. Open `http://<iMac-IP>:8081` and **create your account** (signups start open for exactly this).
2. Then close the door — in the stack folder:
   ```bash
   sed -i 's/VW_SIGNUPS_ALLOWED=true/VW_SIGNUPS_ALLOWED=false/' .env
   docker compose up -d vaultwarden
   ```
3. The admin page is at `http://<iMac-IP>:8081/admin` — the token is `VW_ADMIN_TOKEN` in `.env`. Store that token *inside* your new vault.
4. Install the Bitwarden app/extension you like and point it at your server (`Settings → Self-hosted → http://<iMac-IP>:8081`) — **one catch:** the phone app insists on https. On your home Wi-Fi the web vault works today; for the phone app, do the later upgrade in "Going further" (Nginx Proxy Manager or a tunnel hostname with https) and set `DOMAIN` in `.env` to that https address.

## Step 9 — Syncthing: pair the Mac Studio

1. Open `http://<iMac-IP>:8384`. First thing: **Actions → Settings → GUI** — set a username and strong password (it starts open on the LAN).
2. On the **Mac Studio**, install Syncthing (from syncthing.net, or `brew install --cask syncthing-app` if you use Homebrew there) and open its web GUI.
3. On either machine: **Actions → Show ID** gives a device ID code. On the other machine: **Add Remote Device**, paste it, save. Both sides will ask you to accept — accept on both.
4. Share the folder: on the iMac's Syncthing, add folder path **`/sync`** (that's `~/projects/homelab-stack/sync` on the iMac), and share it with the Studio. On the Studio, choose where it lands (e.g. a `HomelabSync` folder). Drop a test file in — it should appear on the other machine within a minute.
5. Good first jobs for it: the local-agent harness folder (ends the manual re-sync problem) and `~/Sites` content moving Studio → iMac.

## Step 10 — Profiles, when you're ready (any order)

**Paperless (`docs`)** — `docker compose --profile docs up -d`, open `:8001`, log in as `PAPERLESS_ADMIN_USER` / `PAPERLESS_ADMIN_PASSWORD` (from `.env`; change it inside). Drop a PDF into `~/projects/homelab-stack/paperless/consume/` — within a minute it's OCR'd and searchable. That's your grant/manuscript/business-paper archive.

**Stirling-PDF (`tools`)** — open `:8082`, log in with the default credentials from Stirling's own documentation and **change them immediately** in the app settings.

**Karakeep (`tools`, same start command)** — open `:3001`, create your account (the first account is admin). Then lock signups: add `KARAKEEP_DISABLE_SIGNUPS=true` to `.env` and `docker compose --profile tools up -d`. For AI auto-tagging later: it can use a model on the Mac Studio — if Ollama runs there, set `OLLAMA_BASE_URL=http://<Studio-IP>:11434` in `.env`; if you want LM Studio instead, ask in chat and I'll give you the exact two lines for Karakeep's OpenAI-compatible settings.

**AdGuard Home (`network`)** — before starting, confirm port 53 is free on the iMac:
```bash
ss -tulpn | grep ':53 '
```
If something already listens there, stop — tell me what it shows and we'll move it or skip AdGuard. If it's free: `docker compose --profile network up -d`, open `http://<iMac-IP>:3002`, and **in the setup wizard set the Admin Web Interface port to `3000`** (so the dashboard stays at `:3002` afterwards) and DNS port `53`. Then test with ONE device first: set that device's DNS to the iMac's IP. When it behaves, set the router's DNS to the iMac IP and the whole house is filtered.

## Day-to-day commands (all from `~/projects/homelab-stack`)

```bash
docker compose ps                 # what's running
docker compose logs -f ntfy       # watch one app's logs (Ctrl+C exits)
docker compose restart vaultwarden
docker compose down               # stop everything (data in ./data survives)
docker compose up -d              # start core again
./scripts/update.sh               # pull new images + restart core
./scripts/backup.sh               # tar ./data + .env into ~/backups (brief stop)
```

**Backups, honestly:** `backup.sh` covers every app whose data lives in `./data`. Paperless keeps documents in Docker *volumes* — back those up from inside Paperless (Settings → Exporter) or ask me for the one-liner when you start using it. The `sync/` folder is excluded from backups on purpose: Syncthing means it already exists on your other machines.

## Troubleshooting quick hits

- **Homepage loads but a card is grey/red** — that app isn't running (profile apps stay grey until started — that's normal) or crashed: `docker compose logs <name> --tail=50`.
- **Homepage itself refuses to load / "host not allowed"** — `HOMEPAGE_ALLOWED_HOSTS` in `.env` must contain the exact `IP:3000` you typed in the browser. Fix `.env`, then `docker compose up -d homepage`.
- **Healthchecks says CSRF error on login** — same class of fix: the address you browse to must match `SITE_ROOT`/`CSRF_TRUSTED_ORIGINS` (your iMac IP at `:8008`). If the iMac's IP changed, re-run the IP fix below.
- **The iMac's IP changed (router reboot etc.)** — the stack bakes the IP into `.env` and Homepage's links. Set the new IP with `./setup.sh` won't help (`.env` exists) — do: `sed -i 's/OLD_IP/NEW_IP/g' .env homepage/config/services.yaml && docker compose up -d`. Better long-term: give the iMac a static IP / DHCP reservation in the router.
- **Vaultwarden phone app won't connect** — expected until it has an https address; see Step 8 note.
- **AdGuard container exits immediately** — port 53 was already in use; see Step 10.

## Going further (not built, say the word)

- **https names for everything** (`vault.`, `ntfy.` etc. on a `*.dvaughnhouse.org` or a local domain) via the Nginx Proxy Manager you already run + your existing Cloudflare Tunnel — that unlocks the Vaultwarden phone app and Tailscale-friendly names.
- **Wire the ping URLs** from Step 6 into the actual Mission Control / digest / scraper crons.
- **Tier 2 AI stack** (AnythingLLM + SearXNG/Vane + Local Deep Research) — the other option from the shortlist, built the same way for the Studio/InstaBox.

*Configs verified against each project's own docs on 2026-10-21: ntfy (docs.ntfy.sh config + install, incl. the iOS upstream requirement), linuxserver/healthchecks + linuxserver/syncthing image docs, gethomepage installation docs (HOMEPAGE_ALLOWED_HOSTS is required), Vaultwarden wiki patterns, paperless-ngx official compose layout (Postgres + Redis broker), Karakeep's official compose (web + chrome + meilisearch), AdGuard Home + Stirling-PDF image docs.*
