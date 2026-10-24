{# Pure decision: returns {'action': [statements], 'missing': [messages]}. Never creates the proxy, secret, connection or grants. #}
{% macro decisions_bigquery_setup_plan(endpoint, connection, has_function) %}
  {% set n = dbt_decisions.decisions_bigquery_names() %}
  {% set stmts = [] %}
  {% set missing = [] %}
  {% if not endpoint %}{% do missing.append('the endpoint var dbt_decisions_endpoint (the Cloud Run service URL; see README)') %}{% endif %}
  {% if not connection %}{% do missing.append('the connection var dbt_decisions_connection (project.location.connection_id; see README)') %}{% endif %}
  {% if not missing %}
    {% set batch = var('dbt_decisions_max_batching_rows', 100) | int %}
    {% do stmts.append('create schema if not exists `' ~ n['schema_path'] ~ '`') %}
    {% do stmts.append('create or replace function `' ~ n['function'] ~ '`(state json, questions json) returns json remote with connection `' ~ connection ~ '` options (endpoint = ' ~ dbt_decisions.decisions_string_literal(endpoint) ~ ', max_batching_rows = ' ~ batch ~ ')') %}
  {% endif %}
  {{ return({'action': stmts, 'missing': missing}) }}
{% endmacro %}

{% macro bigquery__decisions_setup() %}
  {% set plan = dbt_decisions.decisions_bigquery_setup_plan(var('dbt_decisions_endpoint', ''), var('dbt_decisions_connection', ''), false) %}
  {% for s in plan['action'] %}
    {% do run_query(s) %}
    {% do log('bigquery: setup ran: ' ~ s, info=True) %}
  {% endfor %}
  {% for m in plan['missing'] %}{% do log('bigquery: setup skipped, missing: ' ~ m, info=True) %}{% endfor %}
  {% do dbt_decisions.decisions_doctor() %}
{% endmacro %}
