{% macro duckdb__decisions_setup() %}
  {% set ver = run_query('select version()').rows[0][0] | string | replace('v', '') %}
  {% set parts = ver.split('.') %}
  {% set too_old = (parts[0] | int, parts[1] | int, (parts[2] | int if parts | length > 2 else 0)) < (1, 5, 5) %}
  {% if too_old %}
    {% do log('duckdb: setup skipped, missing: DuckDB >= 1.5.5 is required for the jev community extension (found ' ~ ver ~ ')', info=True) %}
  {% else %}
    {% do run_query('install jev from community') %}
    {% do run_query('load jev') %}
  {% endif %}
  {% do dbt_decisions.decisions_doctor() %}
{% endmacro %}
