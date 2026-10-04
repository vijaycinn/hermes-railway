#!/bin/bash
set -e

# Create every directory hermes expects and seed a default config.yaml if the
# volume is empty. Official image ENV HERMES_HOME=/opt/data (mounted volume),
# so the home IS the volume root: config.yaml, .env, sessions/ etc. live there.
mkdir -p /opt/data/cron /opt/data/sessions /opt/data/logs \
         /opt/data/memories /opt/data/skills /opt/data/platforms/pairing \
         /opt/data/hooks /opt/data/cache/images /opt/data/cache/audio \
         /opt/data/workspace /opt/data/skins /opt/data/plans \
         /opt/data/home

# Stamp the install method as "docker" so hermes treats this as an immutable
# container image, not a pip checkout (keeps the dashboard Update button a
# no-op — the real update path is redeploy with a new image tag).
printf 'docker\n' > /opt/data/.install_method

if [ ! -f /opt/data/config.yaml ] && [ -f /opt/hermes/cli-config.yaml.example ]; then
  cp /opt/hermes/cli-config.yaml.example /opt/data/config.yaml
fi

[ ! -f /opt/data/.env ] && touch /opt/data/.env

# Bootstrap OAuth tokens from env var (e.g. xAI Grok SuperGrok).
# Set HERMES_AUTH_JSON_BOOTSTRAP to the contents of a locally-generated
# auth.json. Written only once — subsequent refreshes update in place.
if [ ! -f /opt/data/auth.json ] && [ -n "${HERMES_AUTH_JSON_BOOTSTRAP}" ]; then
  printf '%s' "${HERMES_AUTH_JSON_BOOTSTRAP}" > /opt/data/auth.json
  chmod 600 /opt/data/auth.json
fi

# Clear stale gateway runtime files from the previous container (persistent
# volume): gateway.pid / gateway.lock / gateway.sock.
rm -f /opt/data/gateway.pid /opt/data/gateway.lock /opt/data/gateway.sock

# Durable lazy-install target for opt-in backends (supermemory, mem0, firecrawl).
export HERMES_LAZY_INSTALL_TARGET=/opt/data/lazy-packages
mkdir -p "$HERMES_LAZY_INSTALL_TARGET"

exec python /app/server.py
