{% macro decision_choice(state, question, choices) %}
  {% do dbt_decisions.decisions_validate_state(state, 'decision_choice') %}
  {% do dbt_decisions.decisions_validate_question(question, 'decision_choice') %}
  {% do dbt_decisions.decisions_validate_choices(choices, 'decision_choice') %}
  {{ return(adapter.dispatch('decision_choice', 'dbt_decisions')(state, question, dbt_decisions.decisions_normalize_choices(choices))) }}
{% endmacro %}

{% macro default__decision_choice(state, question, choices) %}{{ dbt_decisions.decisions_unsupported() }}{% endmacro %}
