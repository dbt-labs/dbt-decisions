{% macro duckdb__decisions_string_literal(s) %}
  {{ return(dbt.string_literal(dbt.escape_single_quotes(s))) }}
{% endmacro %}

{% macro duckdb__decisions_array_literal(items) %}
  {% set parts = [] %}
  {% for i in items %}{% do parts.append(dbt_decisions.decisions_string_literal(i)) %}{% endfor %}
  {{ return('[' ~ parts | join(', ') ~ ']') }}
{% endmacro %}
