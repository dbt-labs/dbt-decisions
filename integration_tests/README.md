# Integration tests

A classic dbt-package integration test project: it installs this package from `../`, builds a small
"Brightloop" support-ticket project on top of it, and checks the results with dbt tests.

It exercises `decision_bundle` (all three question types, with confidence), the scalar macros
(`decision_noul`, `decision_choice`, `decision_score`), NULL and escaping edge cases, and plain SQL
downstream of stored decisions.

| Model | What it covers |
|---|---|
| `ticket_signals` | `decision_bundle` over 80 tickets: noul + choice + score, with confidence |
| `scalar_signals` | the scalar macros with the same questions (a test asserts they match the bundle) |
| `decision_edge_cases` | NULL state, empty string, quotes, backslashes, newlines, non-ASCII |
| `ticket_signals_eval` | decision columns vs. 30 hand labels |
| `at_risk_accounts` | plain SQL over the stored decisions |

The tests check **shape, never quality**: ranges, allowed choices, row counts, NULL handling,
scalar-vs-bundle agreement. So they pass against the mock server and against a live backend alike. The
eval model's accuracy numbers are meaningless on the mock (it is keyword based) and are only checked to exist
and be in range.

Data: 80 tickets, 15 accounts, 30 hand labels, synthetic. A few tickets contain keyword traps on purpose
(T1017 "Not cancelling, I promise :)", T1024, T1050).

## Run on DuckDB with the mock server (no API key)

```bash
cd integration_tests
cp profiles.yml.example profiles.yml          # git-ignored
dbt deps
uv run python3 ../pytests/mock_system_one_server/server.py --port 8765 &
export DECISIONS_API_URL=http://127.0.0.1:8765/local/v1/systemone TYPESAFE_API_KEY=unused
dbt build
```

DuckDB needs a driver for which the `jev` extension is published (v1.5.5 or v1.5.6), see the main README.
With dbt v2: `dbc install "duckdb=1.5.6"`.

The `jev` extension is installed in `on-run-start` and loaded, with the mock endpoint, in each model's
pre-hook (`macros/load_jev.sql`). A plain `SET` in `on-run-start` does not reach the model's connection.
Both macros do nothing on other targets.

## Run live

Unset `DECISIONS_API_URL` and set a real `TYPESAFE_API_KEY` (DuckDB, Postgres, BigQuery proxy, Snowflake secret),
or use a Databricks workspace with `ai_decide`. Then pick the target:

```bash
dbt build --target <duckdb|postgres|databricks|snowflake|bigquery>
```

Each target in `profiles.yml.example` reads its connection from environment variables, and builds into a schema
named after the project, `dbt_decisions_integration_tests` (on Databricks, in the catalog from `DBT_DATABRICKS_CATALOG`).
Databricks needs no TypeSafe key: it uses the built-in `ai_decide`. See the main README
for each warehouse's one-time setup.

## Notes

- `selectors.yml` makes every command skip `function` resources: dbt v2 still tries to build the package's
  Snowflake-only functions on every adapter ([dbt#16875](https://github.com/dbt-labs/dbt/issues/16875)).
- The marts set `+static_analysis: "off"`: dbt v2's parser does not accept the `cross join lateral (...) as x`
  that `decision_bundle` compiles to on DuckDB and Postgres.
- dbt warns `AiProviderUnset (dbt1801)` because the package ships an agent skill. It is harmless here.
- `scalar_matches_bundle` only asserts a match on DuckDB and Postgres, where the scalar macros and the bundle read one
  cached answer. On Databricks, Snowflake and BigQuery the bundle is one call and each scalar macro is its own, and a
  decision model's answers differ a little between prompts (on Databricks: churn up to 0.38 apart, 8 of 80 topics).
- Seeds, models and tests use portable SQL (`dbt.concat`, explicit `group by`) so they build on every
  supported warehouse.
