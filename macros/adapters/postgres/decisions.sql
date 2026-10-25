{# pgjev raises (AttributeError in _jev_eval) when the state is NULL, so every call is guarded:
   NULL in -> NULL out, no remote call (measured; see README). `not (x is null)` rather than `x is not null`
   so that a whole-row `state` (a record) is skipped only when ALL its fields are NULL. `state` appears twice. #}
{% macro decisions_pg_null_guard(state, call) %}
  {{ return('case when not ((' ~ state ~ ') is null) then ' ~ call ~ ' end') }}
{% endmacro %}

{% macro postgres__decision_probability(state, question) %}
  {{ return(dbt_decisions.decisions_pg_null_guard(state, 'jev_prob(' ~ state ~ ', ' ~ dbt_decisions.decisions_string_literal(question) ~ ')')) }}
{% endmacro %}

{% macro postgres__decision_choice(state, question, choices) %}
  {% do dbt_decisions.decisions_warn_unsent_descriptions('decision_choice', choices) %}
  {{ return(dbt_decisions.decisions_pg_null_guard(state, 'jev_choice(' ~ state ~ ', ' ~ dbt_decisions.decisions_string_literal(question) ~ ', ' ~ dbt_decisions.decisions_array_literal(choices.keys() | list) ~ ')')) }}
{% endmacro %}

{% macro postgres__decision_score(state, question, criteria) %}
  {{ return(dbt_decisions.decisions_pg_null_guard(state, 'jev_score(' ~ state ~ ', ' ~ dbt_decisions.decisions_string_literal(question) ~ ', ' ~ dbt_decisions.decisions_array_literal(criteria) ~ ')')) }}
{% endmacro %}

{% macro postgres__decisions_choice_confidence(state, question, choices) %}
  {% do dbt_decisions.decisions_warn_unsent_descriptions('decisions_choice_confidence', choices) %}
  {{ return(dbt_decisions.decisions_pg_null_guard(state, 'jev_confidence(' ~ state ~ ', ' ~ dbt_decisions.decisions_string_literal(question) ~ ", 'choice', " ~ dbt_decisions.decisions_array_literal(choices.keys() | list) ~ ')')) }}
{% endmacro %}

{% macro postgres__decisions_score_confidence(state, question, criteria) %}
  {{ return(dbt_decisions.decisions_pg_null_guard(state, 'jev_confidence(' ~ state ~ ', ' ~ dbt_decisions.decisions_string_literal(question) ~ ", 'score', " ~ dbt_decisions.decisions_array_literal(criteria) ~ ')')) }}
{% endmacro %}

{% macro postgres__decision_bundle(relation, state, questions, passthrough) %}
  {{ return(dbt_decisions.decisions_bundle_scalar_select(relation, state, questions, passthrough)) }}
{% endmacro %}
