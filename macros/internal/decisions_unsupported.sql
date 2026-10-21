{% macro decisions_unsupported() %}
  {{ exceptions.raise_compiler_error("dbt_decisions does not yet support adapter '" ~ target.type ~ "'.") }}
{% endmacro %}
