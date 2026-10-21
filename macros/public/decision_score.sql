{% macro decision_score(state, question, criteria) %}
  {{ return(adapter.dispatch('decision_score', 'dbt_decisions')(state, question, criteria)) }}
{% endmacro %}

{% macro default__decision_score(state, question, criteria) %}{{ dbt_decisions.decisions_unsupported() }}{% endmacro %}
