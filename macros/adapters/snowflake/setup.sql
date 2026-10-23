{# Snowflake object names from the dispatch vars. Secret/rule may be dotted (db.schema.name); otherwise target db/schema. #}
{% macro decisions_snowflake_names() %}
  {% set secret = var('dbt_decisions_secret', target.database ~ '.' ~ target.schema ~ '.jev_api_key') %}
  {% set rule = var('dbt_decisions_network_rule', 'jev_egress') %}
  {% set integration = var('dbt_decisions_integration', 'dbt_decisions_jev_access') %}
  {% set sp = secret.split('.') %}
  {% set rp = rule.split('.') %}
  {% set sdb = (sp[0] if sp | length == 3 else target.database) %}
  {% set ssc = (sp[1] if sp | length == 3 else target.schema) %}
  {% set rdb = (rp[0] if rp | length == 3 else target.database) %}
  {% set rsc = (rp[1] if rp | length == 3 else target.schema) %}
  {{ return({
    'integration': integration,
    'secret': secret, 'secret_name': sp[-1], 'secret_scope': sdb ~ '.' ~ ssc,
    'rule': rdb ~ '.' ~ rsc ~ '.' ~ rp[-1], 'rule_name': rp[-1], 'rule_scope': rdb ~ '.' ~ rsc
  }) }}
{% endmacro %}

{# Pure decision: returns {'action': [statements], 'missing': [messages]}. Never creates a secret, never "or replace". #}
{% macro decisions_snowflake_setup_plan(has_rule, has_integration, has_secret) %}
  {% set n = dbt_decisions.decisions_snowflake_names() %}
  {% set stmts = [] %}
  {% set missing = [] %}
  {% if not has_secret %}
    {% do missing.append('create the secret (see README)') %}
  {% else %}
    {% if not has_rule %}
      {% do stmts.append("create network rule if not exists " ~ n['rule'] ~ " mode = egress type = host_port value_list = ('api.typesafe.ai:443')") %}
    {% endif %}
    {% if not has_integration %}
      {% do stmts.append("create external access integration " ~ n['integration'] ~ " allowed_network_rules = (" ~ n['rule'] ~ ") allowed_authentication_secrets = (" ~ n['secret'] ~ ") enabled = true") %}
    {% endif %}
  {% endif %}
  {{ return({'action': stmts, 'missing': missing}) }}
{% endmacro %}

{% macro snowflake__decisions_setup() %}
  {% set n = dbt_decisions.decisions_snowflake_names() %}
  {% set plan = dbt_decisions.decisions_snowflake_setup_plan(
      run_query("show network rules like '" ~ n['rule_name'] ~ "' in schema " ~ n['rule_scope']).rows | length > 0,
      run_query("show external access integrations like '" ~ n['integration'] ~ "'").rows | length > 0,
      run_query("show secrets like '" ~ n['secret_name'] ~ "' in schema " ~ n['secret_scope']).rows | length > 0) %}
  {% for s in plan['action'] %}
    {% do run_query(s) %}
    {% do log('snowflake: setup ran: ' ~ s, info=True) %}
  {% endfor %}
  {% for m in plan['missing'] %}{% do log('snowflake: setup skipped, missing: ' ~ m, info=True) %}{% endfor %}
  {% do dbt_decisions.decisions_doctor() %}
{% endmacro %}
