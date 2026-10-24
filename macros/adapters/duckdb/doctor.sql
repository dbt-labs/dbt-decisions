{% macro duckdb__decisions_doctor() %}
  {% set ext = run_query("select coalesce(bool_or(installed), false), coalesce(bool_or(loaded), false) from duckdb_extensions() where extension_name = 'jev'") %}
  {% do log('duckdb: jev extension installed: ' ~ (ext.rows[0][0] | string | lower), info=True) %}
  {% do log('duckdb: jev extension loaded: ' ~ (ext.rows[0][1] | string | lower), info=True) %}
  {% set key_set = false %}
  {% if ext.rows[0][1] %}
    {% set k = run_query("select coalesce(bool_or(coalesce(length(value), 0) > 0), false) from duckdb_settings() where name = 'jev_api_key'") %}
    {% set key_set = k.rows[0][0] %}
  {% endif %}
  {% set key_set = key_set or (env_var('TYPESAFE_API_KEY', '') | length > 0) %}
  {% do log('duckdb: api key configured: ' ~ (key_set | string | lower), info=True) %}
{% endmacro %}
