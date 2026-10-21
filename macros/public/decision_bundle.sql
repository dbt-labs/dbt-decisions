{% macro decision_bundle(relation, state, questions, passthrough='*') %}
  {% set rel = relation | string %}
  {% do dbt_decisions.decisions_validate_bundle(rel, state, questions, passthrough) %}
  {{ return(adapter.dispatch('decision_bundle', 'dbt_decisions')(rel, state, questions, passthrough)) }}
{% endmacro %}

{% macro default__decision_bundle(relation, state, questions, passthrough) %}{{ dbt_decisions.decisions_unsupported() }}{% endmacro %}
