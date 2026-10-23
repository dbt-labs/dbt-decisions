{# Overrides of dbt-owned macros. Dispatched in namespace `dbt`; active only when the root project's `dispatch` stanza puts `dbt_decisions` first (see README). #}
{% macro snowflake__get_function_python_options() %}
  {% if model.package_name == 'dbt_decisions' and model.name == 'decisions_ask_json' %}
    {% set integration = var('dbt_decisions_integration', 'dbt_decisions_jev_access') %}
    {% set secret = var('dbt_decisions_secret', target.database ~ '.' ~ target.schema ~ '.jev_api_key') %}
    RUNTIME_VERSION = '{{ model.config.get('runtime_version') }}'
    HANDLER = '{{ model.config.get('entry_point') }}'
    PACKAGES = ('{{ model.config.get('packages', []) | join("','") }}')
    EXTERNAL_ACCESS_INTEGRATIONS = ({{ integration }})
    SECRETS = ('api_key' = {{ secret }})
  {% else %}
    {{ dbt.default__get_function_python_options() }}
  {% endif %}
{% endmacro %}
