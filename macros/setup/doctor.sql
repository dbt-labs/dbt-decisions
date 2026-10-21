{# READ-ONLY environment check. Run: dbt run-operation dbt_decisions.doctor
   Never prints API keys; reports only whether one is configured (boolean). #}
{% macro doctor() %}
  {% do dbt_decisions.decisions_doctor() %}
{% endmacro %}

{% macro decisions_doctor() %}
  {{ return(adapter.dispatch('decisions_doctor', 'dbt_decisions')()) }}
{% endmacro %}

{% macro default__decisions_doctor() %}
  {% do log("dbt_decisions does not yet support adapter '" ~ target.type ~ "'.", info=True) %}
{% endmacro %}
