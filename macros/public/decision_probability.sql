{% macro decision_probability(state, question) %}
  {{ return(adapter.dispatch('decision_probability', 'dbt_decisions')(state, question)) }}
{% endmacro %}

{% macro default__decision_probability(state, question) %}{{ dbt_decisions.decisions_unsupported() }}{% endmacro %}
