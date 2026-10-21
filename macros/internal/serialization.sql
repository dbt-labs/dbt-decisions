{% macro decisions_string_literal(s) %}
  {{ return(adapter.dispatch('decisions_string_literal', 'dbt_decisions')(s)) }}
{% endmacro %}

{% macro default__decisions_string_literal(s) %}
  {{ return(dbt.string_literal(dbt.escape_single_quotes(s))) }}
{% endmacro %}

{% macro decisions_array_literal(items) %}
  {{ return(adapter.dispatch('decisions_array_literal', 'dbt_decisions')(items)) }}
{% endmacro %}

{% macro default__decisions_array_literal(items) %}
  {{ dbt_decisions.decisions_unsupported() }}
{% endmacro %}
