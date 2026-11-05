{% macro decision_noul(state, question) %}
  {% do dbt_decisions.decisions_validate_state(state, 'decision_noul') %}
  {% do dbt_decisions.decisions_validate_question(question, 'decision_noul') %}
  {{ return(adapter.dispatch('decision_noul', 'dbt_decisions')(state, question)) }}
{% endmacro %}

{% macro default__decision_noul(state, question) %}{{ dbt_decisions.decisions_unsupported() }}{% endmacro %}
