#!/usr/bin/env bash
# Native (no-Docker) dev loop: install the engine into .venv, seed the
# warehouse if it's empty, and run the end-to-end proof.
#
# Use this when Docker isn't available (e.g. cloud dev sandboxes). Assumes
# python3.11+, psql, and a reachable Postgres you're allowed to seed.
#
# Usage:
#   WAREHOUSE_DATABASE_URL=postgres://user:pass@host:port/db scripts/dev_native.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${WAREHOUSE_DATABASE_URL:?WAREHOUSE_DATABASE_URL is required (postgres://user:pass@host:port/db)}"

if [ ! -x "$REPO_ROOT/.venv/bin/wren" ]; then
    echo "==> Creating .venv and installing the Wren engine (Apache-2.0, see NOTICE)"
    python3 -m venv "$REPO_ROOT/.venv"
    # mcp pinned <2: wrenai 0.13.3 breaks with mcp 2.x (see engine/Dockerfile).
    "$REPO_ROOT/.venv/bin/pip" install --quiet --upgrade pip
    "$REPO_ROOT/.venv/bin/pip" install --quiet "wrenai[postgres,mcp]==0.13.3" "mcp[cli]>=1.19,<2"
fi
export PATH="$REPO_ROOT/.venv/bin:$PATH"

if [ "$(psql "$WAREHOUSE_DATABASE_URL" -tAc "SELECT to_regclass('public.raw_orders') IS NOT NULL")" != "t" ]; then
    echo "==> Seeding the sample warehouse"
    psql "$WAREHOUSE_DATABASE_URL" -q -f "$REPO_ROOT/sample-warehouse/seed.sql"
else
    echo "==> Warehouse already seeded, skipping"
fi

exec "$REPO_ROOT/scripts/e2e_hardcoded.sh"
