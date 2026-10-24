{% macro bigquery__decisions_doctor() %}
  {% set n = dbt_decisions.decisions_bigquery_names() %}
  {% do log('bigquery: endpoint var set: ' ~ ((var('dbt_decisions_endpoint', '') | length > 0) | string | lower), info=True) %}
  {% do log('bigquery: connection var set: ' ~ ((var('dbt_decisions_connection', '') | length > 0) | string | lower), info=True) %}
  {% set parts = n['schema_path'].split('.') %}
  {% set has_dataset = adapter.check_schema_exists(parts[0], parts[1]) %}
  {% do log('bigquery: dataset ' ~ n['schema_path'] ~ ' exists: ' ~ (has_dataset | string | lower), info=True) %}
  {% if has_dataset %}
    {% set fn = run_query("select count(*) from `" ~ n['schema_path'] ~ "`.INFORMATION_SCHEMA.ROUTINES where routine_name = 'decisions_ask'") %}
    {% do log('bigquery: function decisions_ask exists: ' ~ ((fn.rows[0][0] > 0) | string | lower), info=True) %}
  {% endif %}
  {% do log('bigquery: not checkable from SQL: the Cloud Run proxy, the Secret Manager secret and the connection service account role (roles/run.invoker). See the README.', info=True) %}
{% endmacro %}
