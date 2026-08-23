#!/usr/bin/env bash
# Adilade engine entrypoint: bind the warehouse connection from
# WAREHOUSE_DATABASE_URL, compile the semantic layer, serve MCP over HTTP.
set -euo pipefail

: "${WAREHOUSE_DATABASE_URL:?WAREHOUSE_DATABASE_URL is required (postgres://user:pass@host:port/db)}"
: "${WREN_HOME:=/app/.wren}"
export WREN_HOME
mkdir -p "$WREN_HOME"

# Grounding is non-negotiable: reject SQL referencing tables outside the MDL.
printf '{"strict_mode": true}\n' > "$WREN_HOME/config.json"

# --profile emits JSON (parseable regardless of the mktemp suffix) with $
# escaped for the engine's serve-time secret expansion.
profile_file="$(mktemp)"
python3 /app/engine/connection_from_url.py "$WAREHOUSE_DATABASE_URL" --profile > "$profile_file"
# --no-validate: the warehouse may still be booting; fail at query time instead.
wren profile add warehouse --from-file "$profile_file" --activate --no-validate
rm -f "$profile_file"

(cd /app/semantic && wren context build)

exec wren serve mcp \
    --transport http \
    --host 0.0.0.0 \
    --port "${PORT:-8080}" \
    --project /app/semantic \
    --profile warehouse
