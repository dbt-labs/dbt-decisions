{# DuckDB only; both macros render nothing on other targets.
   install_jev (on-run-start): install the jev community extension once per run.
   load_jev (model pre-hook): load it on the model's own connection and, for mock/offline runs, point it at the mock.
   - DECISIONS_API_URL set: mock/offline. `set global` the endpoint and a non-secret dummy key. It has to be `set global`
     in the model's pre-hook: a plain SET in on-run-start does not reach the model's connection.
   - otherwise: live. The extension reads TYPESAFE_API_KEY from the environment.
   Nothing secret is ever written into SQL. #}
{% macro install_jev() %}
  {% if target.type == 'duckdb' %}install jev from community{% endif %}
{% endmacro %}

{% macro load_jev() %}
  {% if target.type == 'duckdb' %}
    load jev;
    {% if env_var('DECISIONS_API_URL', '') != '' %}
      set global jev_api_url = '{{ env_var("DECISIONS_API_URL") }}';
      set global jev_api_key = 'mock-key';
    {% endif %}
  {% endif %}
{% endmacro %}
