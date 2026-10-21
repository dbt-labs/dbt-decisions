{% macro decisions_string_literal(s) %}
  {{ return(adapter.dispatch('decisions_string_literal', 'dbt_decisions')(s)) }}
{% endmacro %}

{% macro default__decisions_string_literal(s) %}
  {{ return(dbt.string_literal(dbt.escape_single_quotes(s))) }}
{% endmacro %}

{% macro decisions_array_literal(items) %}
  {{ return(adapter.dispatch('decisions_array_literal', 'dbt_decisions')(items)) }}
{% endmacro %}

{% macro default__decisions_array_literal(items) %}
  {{ dbt_decisions.decisions_unsupported() }}
{% endmacro %}

{% macro decisions_question_entry(id, type, instructions, criteria=none) %}
  {# Assemble the object by hand (Fusion's tojson sorts dict keys, so no dict is passed to it): key order is type, instructions,
     criteria. `criteria` is the list of score descriptions, or for type 'choice' the ordered mapping label -> description or none,
     which becomes an object in that order (null when there is no description). Scalars go through tojson. #}
  {% set parts = ['"type": ' ~ tojson(type), '"instructions": ' ~ tojson(instructions)] %}
  {% if criteria is not none %}
    {% if type == 'choice' %}
      {% set entries = [] %}
      {% for label, description in criteria.items() %}{% do entries.append(tojson(label | string) ~ ': ' ~ (tojson(description | string) if description is not none else 'null')) %}{% endfor %}
      {% do parts.append('"criteria": {' ~ entries | join(', ') ~ '}') %}
    {% else %}
      {% do parts.append('"criteria": ' ~ tojson(criteria)) %}
    {% endif %}
  {% endif %}
  {{ return(tojson(id) ~ ': {' ~ parts | join(', ') ~ '}') }}
{% endmacro %}
