# Official Hermes on Railway — auto-tracked

Run the official [NousResearch Hermes container](https://hub.docker.com/r/nousresearch/hermes-agent) on Railway with the battle-tested admin layer from [praveen-ks-2001/hermes-agent-template](https://github.com/praveen-ks-2001/hermes-agent-template), and auto-track upstream releases — no manual audits, no owner middleman.

## Architecture

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
- **server.py**: vendored from the template (attribution below). Web admin (`/setup`), single-login proxy to the native dashboard, gateway start/stop/restart, backup/restore UI, logs panel, `HERMES_DASHBOARD_BASIC_AUTH_*` handling.
- **Volume**: mount Railway volume at **`/opt/data`** (official image's `HERMES_HOME`). Config, sessions, skills, memory survive redeploys.

## How updates work (automatic)

1. Nous publishes release `v2026.9.24` → pushes same-tag image to Docker Hub same day.
2. Action runs daily at 04:13 UTC (+ manual **Run workflow** button): checks `releases/latest`, verifies the Docker Hub tag exists, bumps `ARG HERMES_IMAGE_TAG` in the Dockerfile, commits, pushes.
3. Railway (connected + auto-deploy) redeploys and pulls the new prebuilt image.

Safety: the official image is Nous-tested (no 1,657-file wrapper audits). server.py is stable web plumbing; if an upstream release ever breaks it, test on a throwaway Railway project first (below) before pointing your main deployment at this repo.

## Deploy

1. Railway → New Project → Deploy from GitHub repo → `vijaycinn/hermes-railway`.
2. Add volume mounted at **`/opt/data`**.
3. Set env: `ADMIN_PASSWORD` (required), your provider API keys, optional dashboard basic auth.
4. Deploy. Open the app URL → log in as `admin` / `ADMIN_PASSWORD`.

### Litmus test (recommended before touching a production bot)

Deploy a **throwaway** Railway project from this repo, point it at a **fresh volume**, verify:
- `/health` green
- `/setup` login works
- gateway starts (`hermes gateway status` via Chat terminal, or watch Logs panel)
- Telegram/Discord bot answers
- dashboard renders behind the login

Only if green, point your production service at this repo (or bump `HERMES_IMAGE_TAG`).

### Pin control

- `HERMES_IMAGE_TAG` Railway env var overrides the Dockerfile pin at build time (same pattern as the template's `HERMES_REF`).
- `HERMES_REF` env var only feeds the version string shown in the admin UI.

## Files

| File | Purpose |
|---|---|
| `Dockerfile` | Official image + tini + server.py deps + entrypoint |
| `server.py` | Admin layer (vendored) |
| `start.sh` | Boot: seed dirs, docker stamp, stale gateway files, exec server.py |
| `railway.toml` | Dockerfile build, /health check, restart policy |
| `.github/workflows/bump-version.yml` | Auto release tracker |

## Attribution

`server.py` and the start.sh pattern are vendored from [praveen-ks-2001/hermes-agent-template](https://github.com/praveen-ks-2001/hermes-agent-template) (no license declared upstream) and patched for the official image paths (`/opt/hermes`, `/opt/data`). `start.sh` seeds `cli-config.yaml.example` from the official image's `/opt/hermes/`.
