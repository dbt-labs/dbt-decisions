{% macro databricks__decisions_setup() %}
  {% do dbt_decisions.decisions_doctor() %}
{% endmacro %}
