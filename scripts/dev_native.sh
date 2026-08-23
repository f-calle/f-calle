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

# Preflight: the engine needs python>=3.11 and x86_64 (wren-core-py ships
# no Linux ARM wheels); Debian/Ubuntu need python3-venv installed.
python3 -c 'import sys; sys.exit(sys.version_info < (3, 11))' \
    || { echo "error: python3 >= 3.11 required (found $(python3 -V 2>&1))" >&2; exit 1; }
if [ "$(uname -s)" = "Linux" ] && [ "$(uname -m)" != "x86_64" ]; then
    echo "error: native install needs x86_64 on Linux (wren-core-py has no Linux ARM wheels); use Docker with platform emulation instead" >&2
    exit 1
fi

if [ ! -x "$REPO_ROOT/.venv/bin/wren" ]; then
    echo "==> Creating .venv and installing the Wren engine (Apache-2.0, see NOTICE)"
    python3 -m venv "$REPO_ROOT/.venv" \
        || { echo "error: venv creation failed — on Debian/Ubuntu: sudo apt install python3-venv" >&2; exit 1; }
    # mcp pinned <2: wrenai 0.13.3 breaks with mcp 2.x (see engine/Dockerfile).
    "$REPO_ROOT/.venv/bin/pip" install --quiet --upgrade pip
    "$REPO_ROOT/.venv/bin/pip" install --quiet "wrenai[postgres,mcp]==0.13.3" "wren-core-py==0.7.5" "mcp[cli]>=1.19,<2"
fi
export PATH="$REPO_ROOT/.venv/bin:$PATH"

if [ "$(psql "$WAREHOUSE_DATABASE_URL" -tAc "SELECT to_regclass('public.raw_orders') IS NOT NULL")" != "t" ]; then
    echo "==> Seeding the sample warehouse"
    psql "$WAREHOUSE_DATABASE_URL" -q -f "$REPO_ROOT/sample-warehouse/seed.sql"
else
    echo "==> Warehouse already seeded, skipping"
fi

exec "$REPO_ROOT/scripts/e2e_hardcoded.sh"
