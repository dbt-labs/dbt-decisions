{# Loads the jev DuckDB extension on the model's own connection (run as a pre-hook).
   - DECISIONS_API_URL set (mock/offline runs): point jev at that endpoint with a non-secret dummy key.
   - otherwise (live): load only; the endpoint stays at the extension default and the extension itself
     reads TYPESAFE_API_KEY from the environment. Nothing secret is ever written into SQL. #}
{% macro load_jev() %}
  {% if target.type == 'duckdb' %}
    install jev from community;
    load jev;
    {% if env_var("DECISIONS_API_URL", "") != "" %}
    {% if execute %}
    {{ log('duckdb: DECISIONS_API_URL set, using mock/offline mode for jev extension', info=True) }}
    {% endif %}
    set global jev_api_url = '{{ env_var("DECISIONS_API_URL") }}';
    set global jev_api_key = 'mock-key';
    {% else %}
    {% if execute %}
    {{ log('duckdb: Using TYPESAFE_API_KEY environment variable for TypeSafe API calls', info=True) }}
    {% endif %}
    {% endif %}
  {% endif %}
{% endmacro %}
