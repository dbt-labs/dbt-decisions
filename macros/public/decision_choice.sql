{% macro decision_choice(state, question, choices) %}
  {{ return(adapter.dispatch('decision_choice', 'dbt_decisions')(state, question, choices)) }}
{% endmacro %}

{% macro default__decision_choice(state, question, choices) %}{{ dbt_decisions.decisions_unsupported() }}{% endmacro %}
