{% macro decision_probability(state, question) %}
  {% do dbt_decisions.decisions_validate_state(state, 'decision_probability') %}
  {% do dbt_decisions.decisions_validate_question(question, 'decision_probability') %}
  {{ return(adapter.dispatch('decision_probability', 'dbt_decisions')(state, question)) }}
{% endmacro %}

{% macro default__decision_probability(state, question) %}{{ dbt_decisions.decisions_unsupported() }}{% endmacro %}
