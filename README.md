# Adilade

**Adilade** is a self-hostable, AI-native BI tool for one person: ask a
business question in plain English, get a trusted answer — the SQL
(collapsible), a results table, an auto-selected chart, and a short
explanation — grounded in a governed semantic layer.

It is built on the open-source [Wren AI engine](https://github.com/Canner/WrenAI)
(Apache-2.0; see [NOTICE](./NOTICE) and [LICENSES/](./LICENSES/README.md)),
wrapped — not modified — by a thin Adilade app.

> **The non-negotiable design principle:** accuracy comes from the semantic
> layer, not the model. Every metric, join, and business definition is
> resolved through the governed MDL project in [`semantic/`](./semantic).
> SQL that references anything outside it **fails loudly** instead of
> shipping a believable-but-wrong answer. See
> [ARCHITECTURE.md](./ARCHITECTURE.md) for how that is enforced.

## Status

This is an MVP being built in deliberate steps:

- [x] **1. Repo scaffold** — licensing/attribution, architecture docs
- [x] **2. Engine + sample warehouse** — Wren engine in Docker, seeded
      sample Postgres, one hardcoded question answered end-to-end via the
      CLI (verified: 3-way match between the semantic-SQL path, the
      governed cube path, and an independent raw-SQL ground truth)
- [ ] **3. Web UI** — ask box → generated SQL → results table (single-user,
      password-gated), orchestrated through Claude with engine-validated SQL
- [ ] **4. Charts, explanations, saved questions**
- [ ] **5. Railway deployment** — config, env docs, step-by-step deploy

Deliberately **out** of the MVP: multi-tenant workspaces, row-level access
control, embeddable widgets, sharing.

## Quickstart (Docker Compose)

Requirements: Docker with Compose v2. Images are `linux/amd64` (the
engine's native wheels); Apple Silicon runs them under emulation.

```bash
cp .env.example .env      # defaults work for the bundled sample warehouse
docker compose up --build -d
```

This starts:

| Service | What it is | Where |
|---|---|---|
| `sample-warehouse` | Postgres 16 seeded with a small commerce dataset ([sample-warehouse/seed.sql](./sample-warehouse/seed.sql)) | internal |
| `engine` | The Wren engine serving the governed semantic layer over MCP (strict grounding on) | `127.0.0.1:8080/mcp` (loopback only — the MCP endpoint has no auth) |

Then run the end-to-end proof — the hardcoded question *"What was our total
revenue by month?"* answered through the governed layer, with ungrounded
references rejected and results cross-checked three ways:

```bash
docker compose exec engine adilade-e2e
```

Expected final line:

```
PASS: semantic-SQL path == cube path == raw-SQL ground truth (6 months, 3-way match to the cent)
```

## Quickstart (no Docker)

With python3.11+, `psql`, and a Postgres you can seed:

```bash
WAREHOUSE_DATABASE_URL=postgres://user:pass@localhost:5432/adilade_sample \
  scripts/dev_native.sh
```

This creates `.venv`, installs the pinned engine, seeds the warehouse if
empty, and runs the same end-to-end proof.

## Connecting your own warehouse

Set `WAREHOUSE_DATABASE_URL` in `.env` to your Postgres connection string.
The engine only ever issues read-only queries (its policy layer rejects
anything but SELECTs), but a read-only database role is still the right
setup.

Then describe your data in the semantic layer — that's what makes answers
trustworthy:

1. Models in `semantic/models/<name>/metadata.yml` (tables or SQL-backed).
2. Joins in `semantic/relationships.yml`.
3. Governed metrics in `semantic/cubes/<name>/metadata.yml`
   (e.g. Adilade's sample defines `net_revenue` = completed orders only).
4. Business rules and approved NL→SQL pairs in `semantic/knowledge/`.
5. Rebuild: `docker compose up --build engine` (the image compiles and
   validates the layer at build time), or natively
   `cd semantic && wren context validate && wren context build`.

## Environment variables

All configuration is by env var — see [.env.example](./.env.example) for
the full annotated list. Summary:

| Variable | Purpose | Active since |
|---|---|---|
| `WAREHOUSE_DATABASE_URL` | Postgres the questions run against | step 2 |
| `SAMPLE_WAREHOUSE_PASSWORD` | bundled sample warehouse password (local dev) | step 2 |
| `ANTHROPIC_API_KEY` | bring-your-own LLM key (Claude, orchestrator only) | step 3 |
| `ADILADE_LLM_MODEL` | model id, default `claude-sonnet-5` | step 3 |
| `ADILADE_PASSWORD` | single-user gate for the web UI | step 3 |
| `ENGINE_MCP_URL` | internal engine address for the web app | step 3 |
| `APP_DATABASE_URL` | Adilade's own DB (saved questions) | step 4 |

## Deploying

Railway is the deploy target; the Railway config, service layout, and
step-by-step instructions ship with MVP step 5. Until then the stack runs
anywhere Docker Compose does.

## Working with the semantic layer directly

The engine's CLI is fully available for driving Adilade's semantic layer
by hand (or from your own agent via MCP):

```bash
cd semantic
wren query --sql 'SELECT status, COUNT(*) FROM orders GROUP BY 1' \
  --connection-file <(python3 ../engine/connection_from_url.py "$WAREHOUSE_DATABASE_URL")
wren cube query -c order_metrics --measures net_revenue --time-dimension order_date:month ...
wren dry-plan -d postgres --sql '...'   # see the grounded, expanded SQL
wren serve mcp --transport http         # what the engine container runs
```

## License

Adilade is licensed under the [Apache License 2.0](./LICENSE).

It reuses the Wren AI engine and semantic-layer format from
[Canner/WrenAI](https://github.com/Canner/WrenAI) — Apache-2.0 paths only,
consumed as pinned unmodified PyPI packages plus an adapted example
project. Full provenance: [NOTICE](./NOTICE) and
[LICENSES/README.md](./LICENSES/README.md). "Wren" and "WrenAI" are
trademarks of Canner, Inc.; Adilade is an independent project and is not
affiliated with or endorsed by Canner.
