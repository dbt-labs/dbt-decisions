{% macro snowflake__question_json(type, instructions, criteria=none) %}
  {{ return('{' ~ dbt_decisions.decisions_question_entry('decision', type, instructions, criteria) ~ '}') }}
{% endmacro %}

{% macro snowflake__ask_get(state, question_json, path, as_type) %}
  {{ return(function('dbt_decisions', 'decisions_ask') ~ "(to_variant(" ~ state ~ "), parse_json(" ~ dbt_decisions.decisions_string_literal(question_json) ~ ")):answers:decision:" ~ path ~ "::" ~ as_type) }}
{% endmacro %}

{% macro snowflake__decision_probability(state, question) %}
  {{ return(dbt_decisions.snowflake__ask_get(state, dbt_decisions.snowflake__question_json('noul', question), 'noul', 'float')) }}
{% endmacro %}

{% macro snowflake__decision_choice(state, question, choices) %}
  {{ return(dbt_decisions.snowflake__ask_get(state, dbt_decisions.snowflake__question_json('choice', question, choices), 'choice', 'varchar')) }}
{% endmacro %}

{% macro snowflake__decision_score(state, question, criteria) %}
  {{ return(dbt_decisions.snowflake__ask_get(state, dbt_decisions.snowflake__question_json('score', question, criteria), 'score', 'float')) }}
{% endmacro %}

{# Scalar confidence is refused on Snowflake: a separate decisions_ask call could describe a different answer than the label. #}
{% macro snowflake__decisions_choice_confidence(state, question, choices) %}
  {{ exceptions.raise_compiler_error("dbt_decisions: scalar confidence is not available on Snowflake (a separate decisions_ask call could describe a different answer than the label); use decision_bundle with 'confidence': true") }}
{% endmacro %}

{% macro snowflake__decisions_score_confidence(state, question, criteria) %}
  {{ exceptions.raise_compiler_error("dbt_decisions: scalar confidence is not available on Snowflake (a separate decisions_ask call could describe a different answer than the label); use decision_bundle with 'confidence': true") }}
{% endmacro %}

{% macro snowflake__bundle_get(name, field, as_type) %}
  {{ return('__dd_t.__dd_decision:answers:' ~ name ~ ':' ~ field ~ '::' ~ as_type) }}
{% endmacro %}

{# One decisions_ask call per row in a derived table; the outer select extracts and drops the helper column.
   A NULL state makes the UDF return NULL, so every extracted column is NULL (no guard). #}
{% macro snowflake__decision_bundle(relation, state, questions, passthrough) %}
  {% set cols = [] %}
  {% set entries = [] %}
  {% if passthrough == '*' %}{% do cols.append('__dd_t.* exclude (__dd_decision)') %}{% else %}{% for c in passthrough %}{% do cols.append('__dd_t.' ~ c) %}{% endfor %}{% endif %}
  {% for name, spec in questions.items() %}
    {% if spec['type'] == 'probability' %}
      {% do entries.append(dbt_decisions.decisions_question_entry(name, 'noul', spec['question'])) %}
      {% do cols.append(dbt_decisions.snowflake__bundle_get(name, 'noul', 'float') ~ ' as ' ~ name) %}
    {% elif spec['type'] == 'choice' %}
      {% do entries.append(dbt_decisions.decisions_question_entry(name, 'choice', spec['question'], dbt_decisions.decisions_normalize_choices(spec['choices']))) %}
      {% do cols.append(dbt_decisions.snowflake__bundle_get(name, 'choice', 'varchar') ~ ' as ' ~ name) %}
      {% if spec.get('confidence') %}{% do cols.append(dbt_decisions.snowflake__bundle_get(name, 'confidence', 'float') ~ ' as ' ~ name ~ '_confidence') %}{% endif %}
    {% else %}
      {% do entries.append(dbt_decisions.decisions_question_entry(name, 'score', spec['question'], spec['criteria'])) %}
      {% do cols.append(dbt_decisions.snowflake__bundle_get(name, 'score', 'float') ~ ' as ' ~ name) %}
      {% if spec.get('confidence') %}{% do cols.append(dbt_decisions.snowflake__bundle_get(name, 'confidence', 'float') ~ ' as ' ~ name ~ '_confidence') %}{% endif %}
    {% endif %}
  {% endfor %}
  {% set json = '{' ~ entries | join(', ') ~ '}' %}
  {{ return('select\n    ' ~ cols | join(',\n    ') ~ '\nfrom (select __dd_i.*, ' ~ function('dbt_decisions', 'decisions_ask') ~ '(to_variant(' ~ state ~ '), parse_json(' ~ dbt_decisions.decisions_string_literal(json) ~ ')) as __dd_decision from ' ~ relation ~ ' as __dd_i) as __dd_t') }}
{% endmacro %}
