# Official NousResearch Hermes container + Railway admin layer (server.py).
# Tracked automatically to upstream releases by .github/workflows/bump-version.yml.
ARG HERMES_IMAGE_TAG=v0.21.6
FROM nousresearch/hermes-agent:${HERMES_IMAGE_TAG}

# Build as root; the official image's s6 ENTRYPOINT is overridden below.
USER root

# Real tini. The official image ships a tini->s6 shim at /usr/bin/tini; we
# bypass s6 and let server.py supervise, so install the real reaper.
RUN apt-get -o Acquire::Retries=3 update && \
    apt-get -o Acquire::Retries=3 install -y --no-install-recommends tini && \
    rm -rf /var/lib/apt/lists/*

# server.py dependencies into the image venv (python on PATH = venv python).
RUN /opt/hermes/.venv/bin/pip install --no-cache-dir \
    "starlette>=0.40.0" \
    "uvicorn>=0.31.0" \
    "jinja2>=3.1.0" \
    "python-multipart>=0.0.9" \
    "httpx>=0.27.0" \
    "websockets>=12.0"

COPY server.py /app/server.py
COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh

# server.py supervises the gateway, proxies the native dashboard behind one
# login, and exposes /health. tini reaps gateway/MCP child zombies.
ENTRYPOINT ["/usr/bin/tini", "-g", "--", "/app/start.sh"]
