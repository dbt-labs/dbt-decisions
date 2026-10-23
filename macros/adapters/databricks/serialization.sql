{% macro databricks__decisions_string_literal(s) %}
  {# Spark treats backslash as an escape inside literals: double it, then escape the quote. #}
  {% set escaped = s | replace('\\', '\\\\') | replace("'", "\\'") %}
  {{ return("'" ~ escaped ~ "'") }}
{% endmacro %}
