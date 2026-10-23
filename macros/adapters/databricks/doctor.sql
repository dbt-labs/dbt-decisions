{% macro databricks__decisions_doctor() %}
  {# Jinja has no try/except: if ai_decide is unavailable the adapter error surfaces and aborts. #}
  {% set ver = run_query('select version()') %}
  {% do log('databricks: version: ' ~ ver.rows[0][0], info=True) %}
  {% do log('databricks: probing ai_decide (an unavailable ai_decide surfaces as an adapter error; likely causes: AI Functions Beta not enabled for the workspace, unsupported region, SQL Classic warehouse (use Pro/Serverless), runtime older than DBR 15.4)', info=True) %}
  {% do run_query("select ai_decide('ping', '{\"d\": {\"type\": \"noul\", \"instructions\": \"is this a greeting\"}}')") %}
  {% do log('databricks: ai_decide available: true', info=True) %}
{% endmacro %}
