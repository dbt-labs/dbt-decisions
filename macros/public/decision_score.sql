{% macro decision_score(state, question, criteria) %}
  {% do dbt_decisions.decisions_validate_state(state, 'decision_score') %}
  {% do dbt_decisions.decisions_validate_question(question, 'decision_score') %}
  {% do dbt_decisions.decisions_validate_criteria(criteria, 'decision_score') %}
  {{ return(adapter.dispatch('decision_score', 'dbt_decisions')(state, question, criteria)) }}
{% endmacro %}

{% macro default__decision_score(state, question, criteria) %}{{ dbt_decisions.decisions_unsupported() }}{% endmacro %}
