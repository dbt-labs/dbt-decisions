{% macro duckdb__decision_probability(state, question) %}
  {{ return('jev_prob(' ~ state ~ ', ' ~ dbt_decisions.decisions_string_literal(question) ~ ')') }}
{% endmacro %}

{% macro duckdb__decision_choice(state, question, choices) %}
  {% do dbt_decisions.decisions_warn_unsent_descriptions('decision_choice', choices) %}
  {{ return('jev_choice(' ~ state ~ ', ' ~ dbt_decisions.decisions_string_literal(question) ~ ', ' ~ dbt_decisions.decisions_array_literal(choices.keys() | list) ~ ')') }}
{% endmacro %}

{% macro duckdb__decision_score(state, question, criteria) %}
  {{ return('jev_score(' ~ state ~ ', ' ~ dbt_decisions.decisions_string_literal(question) ~ ', ' ~ dbt_decisions.decisions_array_literal(criteria) ~ ')') }}
{% endmacro %}

{% macro duckdb__decisions_choice_confidence(state, question, choices) %}
  {% do dbt_decisions.decisions_warn_unsent_descriptions('decisions_choice_confidence', choices) %}
  {{ return('jev_confidence(' ~ state ~ ', ' ~ dbt_decisions.decisions_string_literal(question) ~ ", 'choice', " ~ dbt_decisions.decisions_array_literal(choices.keys() | list) ~ ')') }}
{% endmacro %}

{% macro duckdb__decisions_score_confidence(state, question, criteria) %}
  {{ return('jev_confidence(' ~ state ~ ', ' ~ dbt_decisions.decisions_string_literal(question) ~ ", 'score', " ~ dbt_decisions.decisions_array_literal(criteria) ~ ')') }}
{% endmacro %}

{% macro duckdb__decision_bundle(relation, state, questions, passthrough) %}
  {{ return(dbt_decisions.decisions_bundle_scalar_select(relation, state, questions, passthrough)) }}
{% endmacro %}
