# Snowflake

- Engine: a SQL function `decisions_ask` over the Python UDF `decisions_ask_json` (both built by `dbt build`) that calls the Jev service (TypeSafe) through an external access integration. Data leaves Snowflake. Nothing to install beyond the package.
- One-time consumer steps: add the `dispatch` stanza to the root `dbt_project.yml` (without it the package's override is ignored); create the secret yourself; run `dbt build --select "resource_type:function` to build the functions. Needs dbt Core 1.11+.
- `decision_bundle`: one `decisions_ask` call per row for all questions; label and confidence come from that one result.
- Confidence: bundle only. Scalar confidence raises a compile error.
- NULL state: NULL in every output column. Empty string is answered.
- A rejected row yields NULL columns, not an error.
- Number and boolean states are sent as text (`5`, `true`), since a bare number state is rejected.
- Opt out: `functions: dbt_decisions: +enabled: false` in the root `dbt_project.yml`.
- Descriptions: in `criteria` (score) and in a `choices` mapping are sent to the service.
