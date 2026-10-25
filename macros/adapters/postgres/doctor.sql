{% macro postgres__decisions_doctor() %}
  {% set v = run_query('select version()') %}
  {% set plpy = run_query("select count(*) > 0 from pg_available_extensions where name = 'plpython3u'") %}
  {% set jev = run_query("select count(*) > 0 from pg_extension where extname = 'jev'") %}
  {% do log('postgres: version: ' ~ v.rows[0][0], info=True) %}
  {% do log('postgres: plpython3u available: ' ~ (plpy.rows[0][0] | string | lower), info=True) %}
  {% do log('postgres: jev installed: ' ~ (jev.rows[0][0] | string | lower), info=True) %}
{% endmacro %}
