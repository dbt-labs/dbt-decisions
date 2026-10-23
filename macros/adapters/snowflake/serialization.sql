{% macro snowflake__decisions_string_literal(s) %}
  {# Snowflake '...' literals treat backslash as an escape (measured): double it first, then double the quote. #}
  {{ return("'" ~ (s | replace('\\', '\\\\') | replace("'", "''")) ~ "'") }}
{% endmacro %}
