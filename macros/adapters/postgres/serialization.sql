{% macro postgres__decisions_string_literal(s) %}
  {# Backslash is an escape when standard_conforming_strings=off: use the E'' form (valid in both modes). #}
  {% if '\\' in s %}
    {{ return("E'" ~ (s | replace('\\', '\\\\') | replace("'", "''")) ~ "'") }}
  {% else %}
    {{ return(dbt.string_literal(dbt.escape_single_quotes(s))) }}
  {% endif %}
{% endmacro %}

{% macro postgres__decisions_array_literal(items) %}
  {% set parts = [] %}
  {% for i in items %}{% do parts.append(dbt_decisions.decisions_string_literal(i)) %}{% endfor %}
  {{ return('ARRAY[' ~ parts | join(', ') ~ ']') }}
{% endmacro %}
