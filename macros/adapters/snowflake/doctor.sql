{% macro snowflake__decisions_doctor() %}
  {# Presence checks only (show ... like); the secret value is never read. #}
  {% set n = dbt_decisions.decisions_snowflake_names() %}
  {% set fn_scope = target.database ~ '.' ~ target.schema %}
  {% do log('snowflake: version: ' ~ run_query('select current_version()').rows[0][0], info=True) %}
  {% do log('snowflake: external access integration present: ' ~ ((run_query("show external access integrations like '" ~ n['integration'] ~ "'").rows | length > 0) | string | lower), info=True) %}
  {% do log('snowflake: network rule present: ' ~ ((run_query("show network rules like '" ~ n['rule_name'] ~ "' in schema " ~ n['rule_scope']).rows | length > 0) | string | lower), info=True) %}
  {% do log('snowflake: secret present: ' ~ ((run_query("show secrets like '" ~ n['secret_name'] ~ "' in schema " ~ n['secret_scope']).rows | length > 0) | string | lower), info=True) %}
  {# `show functions` name is the second column; match DECISIONS_ASK_JSON exactly (a LIKE pattern would also match other DECISIONS_ASK* names). #}
  {% set fn_rows = run_query("show user functions like 'DECISIONS%' in schema " ~ fn_scope).rows %}
  {% set ns = namespace(has_fn=false) %}
  {% for r in fn_rows %}{% if (r[1] | string | upper) == 'DECISIONS_ASK_JSON' %}{% set ns.has_fn = true %}{% endif %}{% endfor %}
  {% set has_fn = ns.has_fn %}
  {% do log('snowflake: functions present: ' ~ (has_fn | string | lower), info=True) %}
  {% set wired = false %}
  {% if has_fn %}
    {% set ddl = run_query("select get_ddl('function', '" ~ fn_scope ~ ".decisions_ask_json(varchar, varchar)')").rows[0][0] %}
    {% set wired = 'EXTERNAL_ACCESS_INTEGRATIONS' in (ddl | string | upper) %}
  {% endif %}
  {% do log('snowflake: function has integration and secret: ' ~ (wired | string | lower) ~ ('' if wired else ' (run dbt build after adding the dispatch stanza)'), info=True) %}
{% endmacro %}
