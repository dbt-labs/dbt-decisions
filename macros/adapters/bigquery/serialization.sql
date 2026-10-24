{% macro bigquery__decisions_string_literal(s) %}
  {# BigQuery '...' literals treat backslash as an escape and cannot contain a raw newline (measured live 2026-10-16):
     double the backslash first, then escape the quote as \' and newline/carriage return as \n/\r. #}
  {{ return("'" ~ (s | replace('\\', '\\\\') | replace("'", "\\'") | replace('\n', '\\n') | replace('\r', '\\r')) ~ "'") }}
{% endmacro %}
