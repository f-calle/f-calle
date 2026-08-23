# Adilade engine service — the unmodified Wren AI engine (Apache-2.0,
# see /NOTICE) wrapped with Adilade's semantic layer and config.
#
# NOTE: wren-core-py publishes Linux wheels for x86_64 only. Build/run this
# image as linux/amd64 (docker-compose.yml pins `platform`); on Apple
# Silicon, Docker runs it under emulation.
FROM python:3.12-slim

# psql is only used by the e2e proof script (adilade-e2e) for its
# independent ground-truth check.
RUN apt-get update && apt-get install -y --no-install-recommends postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# mcp is pinned <2: wrenai 0.13.3 declares mcp[cli]>=1.19 with no upper
# bound, but mcp 2.0.0 removed mcp.server.fastmcp and breaks `wren serve`.
RUN pip install --no-cache-dir "wrenai[postgres,mcp]==0.13.3" "mcp[cli]>=1.19,<2"

ENV WREN_HOME=/app/.wren \
    WREN_PROJECT_HOME=/app/semantic \
    PYTHONUNBUFFERED=1

WORKDIR /app
COPY semantic/ /app/semantic/
COPY engine/connection_from_url.py engine/entrypoint.sh /app/engine/
COPY scripts/e2e_hardcoded.sh /app/scripts/e2e_hardcoded.sh

# Fail the build early if the semantic layer doesn't compile.
RUN chmod +x /app/engine/entrypoint.sh /app/scripts/e2e_hardcoded.sh \
    && ln -s /app/scripts/e2e_hardcoded.sh /usr/local/bin/adilade-e2e \
    && mkdir -p "$WREN_HOME" \
    && printf '{"strict_mode": true}\n' > "$WREN_HOME/config.json" \
    && cd /app/semantic && wren context validate && wren context build

EXPOSE 8080
ENTRYPOINT ["/app/engine/entrypoint.sh"]
