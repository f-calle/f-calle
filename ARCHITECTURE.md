# Adilade architecture

Single-user, AI-native BI. One design principle outranks everything else:

> **Accuracy comes from the semantic layer, not the model.** The LLM never
> answers from a raw schema. Every question is resolved against the
> governed MDL project in `semantic/`; SQL that references anything the
> semantic layer doesn't define fails loudly before results are shown.

## System shape

```
                 you (single user, password gate)
                          │
                          ▼
        ┌───────────────────────────────────┐
        │ adilade web  (step 3–4, planned)  │   thin, built fresh
        │  ask box · SQL · table · chart ·  │
        │  explanation · saved questions    │
        │  orchestrator: Claude tool-use    │
        │  loop, self-corrects on engine    │
        │  validation errors                │
        └───────┬───────────────┬───────────┘
                │ MCP (HTTP,    │ SQL
                │ internal only)│
                ▼               ▼
   ┌────────────────────┐   ┌──────────────┐
   │ engine  (step 2 ✓) │   │ app db       │   saved questions only —
   │ Wren AI engine,    │   │ (step 4)     │   never warehouse data
   │ unmodified, pinned │   └──────────────┘
   │ + semantic/ MDL    │
   │ + strict grounding │
   └─────────┬──────────┘
             │ psycopg, read-only
             ▼
   ┌────────────────────┐
   │ your warehouse     │   WAREHOUSE_DATABASE_URL
   │ (Postgres; sample  │
   │  bundled for dev)  │
   └────────────────────┘
```

Wrap, don't tangle: the engine is a separate service consuming the
`wrenai` package as published — Adilade adds configuration, the semantic
project, and an entrypoint, but changes no engine code. Upgrading the
engine is a version-pin bump.

## Components

### `engine/` — the Wren engine service (reused, Apache-2.0)

The [Wren AI engine](https://github.com/Canner/WrenAI) (`wrenai==0.13.3` +
`wren-core-py`, pinned; see NOTICE) provides:

- the **MDL semantic layer** compiler (`wren context build`),
- **grounded SQL planning** — SQL written against *model* names is
  CTE-rewritten through the MDL by a DataFusion-based planner,
- the **Postgres connector** (psycopg3, read-only enforced by policy),
- the **MCP server + CLI** — the engine's entire API surface.

The engine has **no built-in LLM** — it is agent-driven by design. That's
exactly the seam Adilade wants: the LLM lives in Adilade's orchestrator
(step 3), and the engine stays the deterministic, governed core.

Startup (`engine/entrypoint.sh`): parse `WAREHOUSE_DATABASE_URL` into a
connection profile → enforce `strict_mode` → compile `semantic/` → serve
MCP over HTTP on the **internal** network. The MCP endpoint has no auth of
its own, so it is never exposed publicly (loopback-only in Compose,
private networking on Railway).

### `semantic/` — the governed layer (ours, versioned in git)

A Wren v5 project (layout adapted from WrenAI's Apache-2.0 `v5-jaffle`
example): models + relationships + views + **cubes** (governed metrics) +
**knowledge** (business rules and approved NL→SQL pairs). This directory
*is* the BI governance: business logic lives here, reviewable and
diff-able, not in prompts and not in the model's imagination.

Sample domain: `customers` (with region) and `orders` (with date/status),
and one deliberately non-trivial governed definition —
`net_revenue = SUM(amount) WHERE status = 'completed'` — that a
schema-guessing agent would plausibly get wrong.

### The grounding gates (verified in step 2)

Four layers, all exercised by `scripts/e2e_hardcoded.sh`:

| Gate | Catches | Verified behavior |
|---|---|---|
| Policy check | any non-SELECT and file/net readers (always enforced, independent of strict mode); tables not in the MDL (`strict_mode: true`, which Adilade enforces everywhere) | `SELECT * FROM payments` → `MODEL_NOT_FOUND … phase=SQL_POLICY_CHECK`, before planning |
| MDL planning (`dry-plan`) | structurally invalid semantic SQL; shows the fully expanded, grounded SQL | plan printed for review |
| Warehouse dry-run (`dry-run`, `LIMIT 0`) | unknown columns, type errors — anything the DB itself rejects | `SELECT profit FROM orders` → `column "profit" does not exist … phase=SQL_DRY_RUN` |
| Cube validation | metrics/dimensions not defined in a cube | `--measures profit_margin` → `Unknown measure` |

Two findings from verification worth pinning down:

- `dry-plan` alone does **not** catch unknown columns (the rewriter can
  fall back and defer to the DB), so the orchestrator's validation gate is
  always *dry-plan + dry-run*, in that order, before any execution.
- `strict_mode` is **off** by default upstream. Adilade turns it on
  everywhere (image build, entrypoint, e2e), making unknown-table
  references a policy error rather than a late planning error.

### The answer path

Today (step 2, CLI): hardcoded question → governed NL→SQL pair from
`semantic/knowledge/` → dry-plan → dry-run → execute → cross-check
(semantic-SQL path vs. cube path vs. independent raw SQL).

Step 3 (orchestrator): question → Claude (via `ANTHROPIC_API_KEY`), with
the engine's MCP tools — schema context (`list_models`, `describe_cube`,
`get_instructions`), recall of approved pairs (`recall_queries`), then
`dry_plan`/`dry_run` validation and `run_sql` execution. Engine validation
errors loop back to the model for self-correction, bounded, and an answer
that never passes validation is reported as a failure — never papered
over. The deterministic path above remains as the regression proof.

## License boundary (see LICENSES/README.md for the audit)

| Layer | Origin | License |
|---|---|---|
| Engine packages (`wrenai`, `wren-core-py`) | WrenAI `core/**`, unmodified, pinned | Apache-2.0 |
| `semantic/` project layout + sample | adapted from WrenAI `examples/v5-jaffle` | Apache-2.0 |
| Everything else (web app, orchestration, scripts, docs) | written for Adilade | Apache-2.0 |
| WrenAI's GenBI app / commercial UI / agentic mode, `docs/**` (CC-BY), logos | **not used** | — |

## Decisions log

1. **Depend on the engine, don't vendor it.** The Apache-2.0 engine is
   consumed as pinned PyPI packages — the same audited code, minus a
   50k-line unreviewable vendor drop. `NOTICE` carries attribution either
   way; upgrades are pin bumps.
2. **MCP is the only engine API.** Upstream removed its REST server; the
   MCP server + CLI is the supported surface. Adilade's web app speaks
   MCP to the engine over the private network.
3. **`mcp` Python SDK pinned `<2`.** wrenai 0.13.3 declares
   `mcp[cli]>=1.19` unbounded; mcp 2.0.0 removed `mcp.server.fastmcp` and
   breaks `wren serve`. Discovered and pinned during verification.
4. **`linux/amd64` images.** `wren-core-py` publishes no Linux ARM
   wheels. Railway is amd64; Apple-Silicon dev machines emulate.
5. **Auth model for one user:** a single password (`ADILADE_PASSWORD`) at
   the web tier; engine and databases are never publicly reachable. No
   user management by design (MVP).
6. **Sample data is honest about governance.** The bundled dataset's
   revenue definition (completed orders only) makes "schema-guessing gets
   it wrong, the semantic layer gets it right" demonstrable, not
   theoretical.
