{% macro decisions_fail(macro_name, arg, message) %}
  {{ exceptions.raise_compiler_error("dbt_decisions." ~ macro_name ~ ": argument '" ~ arg ~ "' " ~ message) }}
{% endmacro %}

{% macro decisions_validate_state(state, macro_name) %}
  {% if state is not string or (state | trim) == '' %}
    {{ dbt_decisions.decisions_fail(macro_name, 'state', 'must be a non-empty SQL expression string') }}
  {% endif %}
{% endmacro %}

{% macro decisions_validate_question(question, macro_name) %}
  {% if question is not string or (question | trim) == '' %}
    {{ dbt_decisions.decisions_fail(macro_name, 'question', 'must be a non-empty string known at compile time') }}
  {% endif %}
{% endmacro %}

{% macro decisions_validate_choices(choices, macro_name) %}
  {% if choices is string or choices is not iterable %}
    {{ dbt_decisions.decisions_fail(macro_name, 'choices', 'must be a list of strings or a mapping of label to description') }}
  {% endif %}
  {% set items = choices | list %}
  {% if items | length == 0 %}
    {{ dbt_decisions.decisions_fail(macro_name, 'choices', 'must contain at least one choice') }}
  {% endif %}
  {% if items | length > 255 %}
    {{ dbt_decisions.decisions_fail(macro_name, 'choices', 'must contain at most 255 choices, got ' ~ (items | length)) }}
  {% endif %}
  {% set seen = [] %}
  {% for c in items %}
    {% if c is not string %}
      {{ dbt_decisions.decisions_fail(macro_name, 'choices', ('labels must be strings, got ' if choices is mapping else 'must contain only strings, got ') ~ c) }}
    {% endif %}
    {% if (c | trim) == '' %}
      {{ dbt_decisions.decisions_fail(macro_name, 'choices', 'must not contain an empty choice') }}
    {% endif %}
    {% if c in seen %}
      {{ dbt_decisions.decisions_fail(macro_name, 'choices', "contains a duplicate choice: '" ~ c ~ "'") }}
    {% endif %}
    {% do seen.append(c) %}
    {% if choices is mapping %}
      {% set d = choices[c] %}
      {% if d is not none and (d is not string or (d | trim) == '') %}
        {{ dbt_decisions.decisions_fail(macro_name, 'choices', "description for '" ~ c ~ "' must be a non-empty string or none") }}
      {% endif %}
    {% endif %}
  {% endfor %}
{% endmacro %}

{# Ordered mapping label -> description or none, from either accepted form. Call after decisions_validate_choices. #}
{% macro decisions_normalize_choices(choices) %}
  {% set d = {} %}
  {% if choices is mapping %}
    {% for k, v in choices.items() %}{% do d.update({k: v}) %}{% endfor %}
  {% else %}
    {% for k in choices %}{% do d.update({k: none}) %}{% endfor %}
  {% endif %}
  {{ return(d) }}
{% endmacro %}

{% macro decisions_warn_unsent_descriptions(macro_name, choices) %}
  {% set ns = namespace(any=false) %}
  {% for k, v in choices.items() %}{% if v is not none %}{% set ns.any = true %}{% endif %}{% endfor %}
  {% if ns.any %}
    {% do exceptions.warn("dbt_decisions." ~ macro_name ~ ": choice descriptions are not sent on " ~ target.type ~ "; only the labels are used") %}
  {% endif %}
{% endmacro %}

{% macro decisions_validate_criteria(criteria, macro_name) %}
  {% if criteria is string or criteria is mapping or criteria is not iterable %}
    {{ dbt_decisions.decisions_fail(macro_name, 'criteria', 'must be a list of 2 to 10 strings') }}
  {% endif %}
  {% set items = criteria | list %}
  {% if items | length < 2 or items | length > 10 %}
    {{ dbt_decisions.decisions_fail(macro_name, 'criteria', 'must be a list of 2 to 10 strings, got ' ~ (items | length)) }}
  {% endif %}
  {% set seen = [] %}
  {% for c in items %}
    {% if c is not string %}
      {{ dbt_decisions.decisions_fail(macro_name, 'criteria', 'must contain only strings, got ' ~ c) }}
    {% endif %}
    {% if (c | trim) == '' %}
      {{ dbt_decisions.decisions_fail(macro_name, 'criteria', 'must not contain an empty criterion') }}
    {% endif %}
    {% if c in seen %}
      {{ dbt_decisions.decisions_fail(macro_name, 'criteria', "contains a duplicate criterion: '" ~ c ~ "'") }}
    {% endif %}
    {% do seen.append(c) %}
  {% endfor %}
{% endmacro %}
