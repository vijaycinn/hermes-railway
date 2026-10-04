# Official Hermes on Railway — auto-tracked

Run the official [NousResearch Hermes container](https://hub.docker.com/r/nousresearch/hermes-agent) on Railway with the battle-tested admin layer from [praveen-ks-2001/hermes-agent-template](https://github.com/praveen-ks-2001/hermes-agent-template), and auto-track upstream releases — no manual audits, no owner middleman.

```
NousResearch/hermes-agent  (releases + Docker Hub images: nousresearch/hermes-agent:vYYYY.M.D)
        │  Dockerfile: FROM nousresearch/hermes-agent:<tag>
        ▼
vijaycinn/hermes-railway   (this repo)
        │  .github/workflows/bump-version.yml polls releases daily,
        │  bumps ARG HERMES_IMAGE_TAG, pushes to main
        ▼
Railway                    (connected to this repo, auto-deploy on)
        │  pulls the prebuilt official image, runs server.py on top
        ▼
container                  (server.py = admin UI + gateway supervision + /health)
```

- **Image**: official `nousresearch/hermes-agent` (s6 supervision, SQLite 3.53.4, pinned Chromium baked in). No source builds at deploy time.
- **server.py**: vendored from the template. Web admin (`/setup`), single-login proxy to the native dashboard, gateway start/stop/restart, backup/restore UI, logs panel, dashboard basic-auth handling.
- **Volume**: mounted at **`/opt/data`** (official image's `HERMES_HOME`). Config, sessions, skills, memory survive redeploys.

---

## Railway setup — manual walkthrough

### 1. Create the project

1. Railway dashboard → **New Project** → **Deploy from GitHub repo** → select **`vijaycinn/hermes-railway`** (authorize the GitHub App if prompted).
2. Wait for the first deploy to build (pulls the official image + installs 6 small Python packages). You can configure the next steps while it builds.

### 2. Add the volume (required — this is your persistent home)

1. Service → **Settings** → **Volumes** → **New Volume**.
2. **Mount path: `/opt/data`** (exact — this is `HERMES_HOME`; everything lives here).
3. Size:
   - Litmus/test container: **1 GB** is enough to start.
   - Production bot: **2–5 GB**. Sessions, logs, browser caches, and lazy-install packages grow over time.

### 3. Set variables (Settings → Variables)

| Variable | Required | Value |
|---|---|---|
| `ADMIN_PASSWORD` | **yes** | Login password for `/setup` (admin panel). |
| `OPENROUTER_API_KEY` (or Anthropic/OpenAI/DeepSeek key) | **yes** | Provider key. Gateway won't auto-start until a provider is configured (see step 5). |
| `HERMES_DASHBOARD_BASIC_AUTH_USERNAME` | no | Username for the proxied native dashboard. |
| `HERMES_DASHBOARD_BASIC_AUTH_PASSWORD` | no | Password for the proxied native dashboard. |
| `HERMES_REF` | no | Version string shown in the admin UI (defaults to empty). Cosmetic. |
| `HERMES_AUTH_JSON_BOOTSTRAP` | no | Contents of a local `auth.json` to bootstrap OAuth tokens on first boot. |
| `HERMES_IMAGE_TAG` | no | Build-time override for the pinned image tag (wins over Dockerfile `ARG`). |

### 4. Sizing (CPU / RAM)

**Minimum for a working bot (litmus test): 2 GB RAM / 1 vCPU.**

**Recommended (production, matches the reference deployment): 3 GB RAM / 1 vCPU.**

Why: the gateway alone holds ~650 MB steady (its floor), plus the admin server, dashboard proxy, and headroom for MCP servers, browser/computer-use tools, and deploys. Railway's RAM meter counts page cache as used — it's reclaimable, so don't panic if reported usage approaches the cap; watch it over a week. If you plan to run several MCP servers, choose 4 GB / 1 vCPU.

CPU: 1 vCPU minimum for either tier. 0.5 vCPU works but makes deploys and tool installs sluggish.

### 5. First boot — provider setup

1. Open your app URL (Railway → project → **Settings** → **Networking** → **Generate Domain**, or the provided `*.up.railway.app`).
2. Log in at `/setup` with `admin` / your `ADMIN_PASSWORD`.
3. Complete the provider/channel wizard — pick your model provider and add the Telegram/Discord bot token if you're wiring a bot.
4. The gateway auto-starts once config is complete. Watch the **Logs** panel for `Gateway.start()`.

### 6. Verify it works

- `https://<your-app>/health` → `200` (Railway healthcheck uses the same `/health`).
- `/setup` logs in and shows no errors.
- Logs show the gateway running; send a test message to your bot (Telegram/Discord) and confirm it answers.
- Open the native dashboard through `/setup` (proxied behind the single login) — should render, not 503.

---

## Auto-updates

1. Nous publishes a release (e.g. `v2026.9.24`) → same-tag image lands on Docker Hub the same day.
2. This repo's action **Track Hermes releases** runs daily at 04:13 UTC and on the manual **Run workflow** button: it reads `releases/latest`, verifies the Docker Hub tag exists, bumps `ARG HERMES_IMAGE_TAG` in the `Dockerfile`, commits, pushes.
3. Railway (repo connected + **Auto Deploy** on) redeploys and pulls the new prebuilt image.

Expect up to ~24 h lag. To force it: GitHub → Actions → **Track Hermes releases** → **Run workflow** → wait for the commit → Railway deploys.

**Pin control**: set `HERMES_IMAGE_TAG` in Railway to freeze on a specific version (e.g. `v2026.9.21`) and ignore the auto-bumps until you're ready.

### Litmus test before touching a production bot

1. Deploy a **throwaway** Railway project from this repo with a **fresh volume**.
2. Walk steps 1–6 above. Verify `/health`, `/setup`, gateway start, bot replies, dashboard renders.
3. Only if green, point your production service at this repo (Settings → Source → change repo/branch, or set `HERMES_IMAGE_TAG`) and redeploy.

---

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Gateway never starts after `/setup` | `server.py`'s boot gate needs `LLM_MODEL` + one provider key in `$HERMES_HOME/.env` (volume). Complete the `/setup` wizard fully; check Logs. |
| `/health` green but bot silent | Check `$HERMES_HOME/ESTOP` sentinel on the volume (blocks turns while bot shows online). Remove it, restart gateway from the panel. |
| Dashboard pages 503 behind login | `HERMES_DASHBOARD_PUBLIC_URL` must be set only together with basic-auth credentials — leave it unset unless you set both auth vars. |
| "Update Hermes" button in dashboard | No-op on this container (install stamped `docker`) — real update = new image + redeploy. |
| Stuck on old version | Auto-deploy off, or `HERMES_IMAGE_TAG` override set. Check Actions → last run; click **Run workflow**. |

---

## Files

| File | Purpose |
|---|---|
| `Dockerfile` | Official image + tini + server.py deps + entrypoint |
| `server.py` | Admin layer (vendored) |
| `start.sh` | Boot: seed dirs, docker stamp, stale gateway files, exec server.py |
| `railway.toml` | Dockerfile build, `/health` check, restart policy |
| `.github/workflows/bump-version.yml` | Auto release tracker |

## Attribution

`server.py` and the start.sh pattern are vendored from [praveen-ks-2001/hermes-agent-template](https://github.com/praveen-ks-2001/hermes-agent-template) (no license declared upstream) and patched for the official image paths (`/opt/hermes`, `/opt/data`). `start.sh` seeds `cli-config.yaml.example` from the official image's `/opt/hermes/`.
