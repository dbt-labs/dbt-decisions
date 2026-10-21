{# Explicit, opt-in setup. Run: dbt run-operation dbt_decisions.setup  (never part of dbt run) #}
{% macro setup() %}
  {% do dbt_decisions.decisions_setup() %}
{% endmacro %}

{% macro decisions_setup() %}
  {{ return(adapter.dispatch('decisions_setup', 'dbt_decisions')()) }}
{% endmacro %}

{% macro default__decisions_setup() %}
  {% do log("dbt_decisions does not yet support adapter '" ~ target.type ~ "'.", info=True) %}
{% endmacro %}
