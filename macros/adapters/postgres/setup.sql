{# Pure decision: returns {'action': 'create'|'skip', 'missing': [messages]} #}
{% macro decisions_pg_setup_plan(has_plpy, has_jev_files, is_superuser) %}
  {% set missing = [] %}
  {% if not has_plpy %}{% do missing.append('plpython3u extension is not available on this server (install the postgresql-plpython3 package)') %}{% endif %}
  {% if not has_jev_files %}{% do missing.append('jev extension files are not installed on this server (jev is not in pg_available_extensions)') %}{% endif %}
  {% if not is_superuser %}{% do missing.append('a superuser is required (jev depends on the untrusted language plpython3u)') %}{% endif %}
  {{ return({'action': ('skip' if missing else 'create'), 'missing': missing}) }}
{% endmacro %}

{% macro postgres__decisions_setup() %}
  {% set plan = dbt_decisions.decisions_pg_setup_plan(
      run_query("select count(*) > 0 from pg_available_extensions where name = 'plpython3u'").rows[0][0],
      run_query("select count(*) > 0 from pg_available_extensions where name = 'jev'").rows[0][0],
      run_query("select rolsuper from pg_roles where rolname = current_user").rows[0][0]) %}
  {% if plan['action'] == 'create' %}
    {% do run_query('create extension if not exists jev cascade') %}
    {% do log('postgres: setup ran: create extension if not exists jev cascade', info=True) %}
  {% else %}
    {% for m in plan['missing'] %}{% do log('postgres: setup skipped, missing: ' ~ m, info=True) %}{% endfor %}
  {% endif %}
  {% do dbt_decisions.decisions_doctor() %}
{% endmacro %}
