# Integration tests

A classic dbt-package integration test project for **Databricks**, the one supported warehouse with built-in
decision models (`ai_decide`), so it needs no TypeSafe API key. It installs this package from `../`, builds a small
"Brightloop" support-ticket project on top of it, and checks the results with dbt tests.

| Model | What it covers |
|---|---|
| `ticket_signals` | `decision_bundle` over 80 tickets: noul + choice + score, with confidence |
| `scalar_signals` | the scalar macros (`decision_noul`, `decision_choice`, `decision_score`) |
| `decision_edge_cases` | NULL state, empty string, quotes, backslashes, newlines, non-ASCII |
| `ticket_signals_eval` | decision columns vs. 30 hand labels |
| `at_risk_accounts` | plain SQL over the stored decisions |

The tests check **shape, never quality**: ranges, allowed choices, row counts, NULL handling. The eval model's
accuracy numbers are only checked to exist and be in range.

Data: 80 tickets, 15 accounts, 30 hand labels, synthetic. A few tickets contain keyword traps on purpose
(T1017 "Not cancelling, I promise :)", T1024, T1050).

## Run

Requirements are in the main README (AI Functions Beta enabled, Pro or Serverless SQL warehouse).

```bash
cd integration_tests
cp profiles.yml.example profiles.yml     # git-ignored
export DBT_DATABRICKS_HOST_NAME=... DBT_DATABRICKS_HTTP_PATH=... DBT_DATABRICKS_CATALOG=...
dbt deps
dbt build
```

Everything builds into the schema `dbt_decisions_integration_tests`. The profile uses browser login (OAuth);
swap in `token:` if you prefer.

## Notes

- `selectors.yml` makes every command skip `function` resources: dbt v2 still tries to build the package's
  Snowflake-only functions on Databricks, and they fail
  ([dbt#16875](https://github.com/dbt-labs/dbt/issues/16875)).
- The scalar macros and `decision_bundle` are not compared: the bundle is one `ai_decide` call for all questions
  and each scalar macro is its own, and a decision model's answers differ a little between prompts (measured:
  churn up to 0.38 apart, 8 of 80 topics).
- dbt warns `AiProviderUnset (dbt1801)` because the package ships an agent skill. It is harmless here.
- Other warehouses are out of scope for now. Databricks is the only one with a built-in decision model; the others
  need a TypeSafe key and their own setup.
