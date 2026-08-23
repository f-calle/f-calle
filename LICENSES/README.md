# Licensing and provenance

Adilade as a whole is licensed under the **Apache License 2.0** — see
[`/LICENSE`](../LICENSE). This folder documents where reused third-party
code comes from and under which terms.

## Upstream: WrenAI (Canner, Inc.)

Adilade is built on the Wren AI engine. WrenAI is multi-licensed **by
path**; a verbatim copy of its license overview is kept here as
[`wrenai-LICENSE`](./wrenai-LICENSE). The audit below was performed against
WrenAI commit `f2841bcbdf8daed9cab9bd5d83275bc51c176594`.

| WrenAI path | License | Used by Adilade? |
|---|---|---|
| `core/**` (engine, MDL, connectors, CLI, MCP server) | Apache-2.0 | **Yes** — as the pinned `wrenai` / `wren-core-py` PyPI packages |
| `sdk/**` (LangChain / Pydantic AI toolkits) | Apache-2.0 | Not currently (may be reused later) |
| `skills/**` (agent skill stubs) | Apache-2.0 | Not currently |
| `examples/**` (`v5-jaffle` sample project) | Apache-2.0 | **Yes** — adapted into `semantic/` |
| Root files (LICENSE, README, …) | Apache-2.0 | License texts copied here for attribution |
| `docs/**` | CC BY 4.0 | **No** (excluded by policy: Apache-2.0 code only) |
| AGPL-3.0 modules | Reserved for future WrenAI modules; **none exist** at the audited commit | **No** |
| Legacy GenBI app (`legacy/v1` branch), Wren commercial UI / agentic mode | Not part of the audited tree | **No** |
| WrenAI logos / "Wren" & "WrenAI" names | Trademarks of Canner, Inc. — explicitly **not** licensed | **No** (nominative attribution only) |

Every package manifest under the reused paths (`Cargo.toml`,
`pyproject.toml`, `package.json`) declares Apache-2.0; the audit and an
independent adversarial re-check found zero AGPL/commercial/proprietary
license markers in those paths at the pinned commit.

## Files in this folder

| File | What it is |
|---|---|
| `wrenai-LICENSE` | Verbatim copy of WrenAI's root `LICENSE` (the path → license map) |
| `wrenai-LICENSE-APACHE-2.0` | Verbatim Apache-2.0 text as shipped by WrenAI |

## Obligations we carry (Apache-2.0 §4)

- Redistributions of the reused code keep the Apache-2.0 license text
  (this folder) and attribution ([`/NOTICE`](../NOTICE)).
- Modifications to adapted files (the `semantic/` project derived from
  `examples/v5-jaffle`) are marked as adapted in `/NOTICE`.
- We do not use the Wren name or logos to brand this product.
