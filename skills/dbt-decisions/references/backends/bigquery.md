# BigQuery

- Engine: a remote function `decisions_ask` (created by `dbt_decisions.setup`) that calls a Cloud Run proxy (`bigquery_proxy/`), which forwards to the Jev service (TypeSafe). You deploy the proxy, the secret and the connection yourself (README).
- One-time consumer steps: the README gcloud/bq sequence, then `dbt run-operation dbt_decisions.setup` with `dbt_decisions_endpoint` and `dbt_decisions_connection` vars. Grant the connection's service account `roles/run.invoker`; expect a 403 for a minute or more after granting.
- Confidence: bundle only. Scalar confidence raises a compile error.
- NULL state: NULL in every output column.
- Descriptions: in `criteria` (score) and in a `choices` mapping are sent to the service.
