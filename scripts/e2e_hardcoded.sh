#!/usr/bin/env bash
# Adilade MVP step-2 proof: one hardcoded business question answered
# end-to-end through the governed semantic layer, via the Wren engine CLI.
#
#   Question (hardcoded): "What was our total revenue by month?"
#
# The answer is only accepted if:
#   * the SQL is resolved from the governed knowledge base, not invented;
#   * it plans through the MDL (dry-plan) and validates against the
#     warehouse (dry-run) BEFORE execution;
#   * ungrounded references fail loudly (unknown table, unknown column,
#     unknown cube measure);
#   * the semantic-SQL path, the governed cube path, and an independent
#     raw-SQL ground truth all agree to the cent.
#
# Requirements: the `wren` CLI (pip install "wrenai[postgres]==0.13.3"),
# python3 with PyYAML (a wrenai dependency), psql, and a warehouse seeded
# with sample-warehouse/seed.sql.
#
# Usage:
#   WAREHOUSE_DATABASE_URL=postgres://user:pass@host:port/db scripts/e2e_hardcoded.sh
set -euo pipefail

# readlink -f: the script is also invoked through the /usr/local/bin/adilade-e2e
# symlink inside the engine image, so resolve to the real path first.
REPO_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
SEMANTIC_DIR="${SEMANTIC_DIR:-$REPO_ROOT/semantic}"
: "${WAREHOUSE_DATABASE_URL:?WAREHOUSE_DATABASE_URL is required (postgres://user:pass@host:port/db)}"

command -v wren >/dev/null || { echo "error: wren CLI not found (pip install 'wrenai[postgres]==0.13.3')" >&2; exit 1; }
command -v psql >/dev/null || { echo "error: psql not found (needed for the independent ground-truth check)" >&2; exit 1; }

# Isolated engine home with grounding enforced, so the test never depends on
# (or pollutes) the caller's ~/.wren state.
WREN_HOME="$(mktemp -d)"
export WREN_HOME
printf '{"strict_mode": true}\n' > "$WREN_HOME/config.json"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK" "$WREN_HOME"' EXIT
CONN_JSON="$WORK/conn.json"
python3 "$REPO_ROOT/engine/connection_from_url.py" "$WAREHOUSE_DATABASE_URL" > "$CONN_JSON"

step() { printf '\n\033[1m[%s] %s\033[0m\n' "$1" "$2"; }

step 1/6 "Compile the semantic layer (wren context validate + build)"
(cd "$SEMANTIC_DIR" && wren context validate && wren context build)

step 2/6 "Resolve the hardcoded question from the governed knowledge base"
KNOWLEDGE_FILE="$SEMANTIC_DIR/knowledge/sql/revenue-by-month.md"
QUESTION="$(python3 - "$KNOWLEDGE_FILE" <<'PY'
import sys, yaml
front = open(sys.argv[1]).read().split("---")[1]
print(yaml.safe_load(front)["nl"])
PY
)"
SQL="$(python3 - "$KNOWLEDGE_FILE" <<'PY'
import sys, yaml
front = open(sys.argv[1]).read().split("---")[1]
print(yaml.safe_load(front)["sql"].strip())
PY
)"
echo "  question: $QUESTION"
echo "  governed SQL (from $(basename "$KNOWLEDGE_FILE")):"
echo "$SQL" | sed 's/^/    /'

step 3/6 "Grounding gate: ungrounded references must FAIL loudly"
cd "$SEMANTIC_DIR"
if wren dry-plan -d postgres --sql 'SELECT * FROM payments' >/dev/null 2>&1; then
    echo "  FAIL: unknown table 'payments' was not rejected" >&2; exit 1
fi
echo "  ok: unknown table rejected by strict-mode policy (dry-plan)"
if wren dry-run --connection-file "$CONN_JSON" --sql 'SELECT profit FROM orders' >/dev/null 2>&1; then
    echo "  FAIL: unknown column 'profit' was not rejected" >&2; exit 1
fi
echo "  ok: unknown column rejected by warehouse validation (dry-run)"
if wren cube query -c order_metrics --measures profit_margin --connection-file "$CONN_JSON" >/dev/null 2>&1; then
    echo "  FAIL: unknown cube measure 'profit_margin' was not rejected" >&2; exit 1
fi
echo "  ok: unknown cube measure rejected (cube query)"

step 4/6 "Validate the governed SQL before executing (dry-plan + dry-run)"
wren dry-plan -d postgres --sql "$SQL" | sed 's/^/  plan: /'
wren dry-run --connection-file "$CONN_JSON" --sql "$SQL" >/dev/null
echo "  ok: dry-run passed against the warehouse"

step 5/6 "Execute: semantic-SQL path and governed cube path"
wren query -q -o json --connection-file "$CONN_JSON" --sql "$SQL" > "$WORK/sql_path.jsonl"
sed 's/^/  sql-path:  /' "$WORK/sql_path.jsonl"
wren cube query -c order_metrics --measures net_revenue --time-dimension "order_date:month" \
    -o json --connection-file "$CONN_JSON" > "$WORK/cube_path.jsonl"
sed 's/^/  cube-path: /' "$WORK/cube_path.jsonl"

step 6/6 "Cross-check against independent raw-SQL ground truth (psql)"
psql "$WAREHOUSE_DATABASE_URL" -tA -F'|' -c "
    SELECT to_char(date_trunc('month', order_date), 'YYYY-MM'),
           ROUND(SUM(CASE WHEN status = 'completed' THEN amount ELSE 0 END)::numeric, 2)
    FROM public.raw_orders
    GROUP BY 1 ORDER BY 1" > "$WORK/ground_truth.psv"

python3 - "$WORK" <<'PY'
import datetime, json, pathlib, sys

work = pathlib.Path(sys.argv[1])

def month_of(epoch_ms):  # engine emits DATE_TRUNC months as epoch millis (UTC)
    return datetime.datetime.fromtimestamp(epoch_ms / 1000, tz=datetime.timezone.utc).strftime("%Y-%m")

def load_jsonl(path, month_key, value_key):
    out = {}
    for line in path.read_text().splitlines():
        if line.strip():
            row = json.loads(line)
            out[month_of(row[month_key])] = round(float(row[value_key]), 2)
    return out

sql_path = load_jsonl(work / "sql_path.jsonl", "month", "net_revenue")
cube_path = load_jsonl(work / "cube_path.jsonl", "order_date__month", "net_revenue")
truth = {}
for line in (work / "ground_truth.psv").read_text().splitlines():
    if line.strip():
        month, value = line.split("|")
        truth[month] = round(float(value), 2)

assert truth, "ground truth query returned no rows — is the warehouse seeded?"
for name, result in (("semantic-SQL", sql_path), ("cube", cube_path)):
    assert result == truth, f"{name} path disagrees with ground truth:\n  {result}\n  {truth}"

print("\n  month    net_revenue (USD)")
for month, value in sorted(truth.items()):
    print(f"  {month}  {value:>12.2f}")
print(f"  TOTAL    {sum(truth.values()):>12.2f}")
print("\nPASS: semantic-SQL path == cube path == raw-SQL ground truth "
      f"({len(truth)} months, 3-way match to the cent)")
PY
