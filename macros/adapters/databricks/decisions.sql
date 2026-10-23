{% macro databricks__question_json(type, instructions, criteria=none) %}
  {{ return('{' ~ dbt_decisions.decisions_question_entry('decision', type, instructions, criteria) ~ '}') }}
{% endmacro %}

{% macro databricks__bundle_get(name, field, as_type) %}
  {{ return("variant_get(__dd_t.__dd_decision, '$.response.answers." ~ name ~ "." ~ field ~ "', '" ~ as_type ~ "')") }}
{% endmacro %}

{# Not a lateral join: Databricks rejects `cross join lateral (select ai_decide(...))` (SQLSTATE 0A000, correlated use of
   ai_decide). A derived table computes the decision once per row; the outer select extracts and drops the helper column.
   `state` is written over the relation's own columns, exactly as given (the inner alias __dd_i does not affect unqualified references). #}
{% macro databricks__decision_bundle(relation, state, questions, passthrough) %}
  {% set cols = [] %}
  {% set entries = [] %}
  {% if passthrough == '*' %}{% do cols.append('* except (__dd_decision)') %}{% else %}{% for c in passthrough %}{% do cols.append('__dd_t.' ~ c) %}{% endfor %}{% endif %}
  {% for name, spec in questions.items() %}
    {% if spec['type'] == 'probability' %}
      {% do entries.append(dbt_decisions.decisions_question_entry(name, 'noul', spec['question'])) %}
      {% do cols.append(dbt_decisions.databricks__bundle_get(name, 'probability', 'double') ~ ' as ' ~ name) %}
    {% elif spec['type'] == 'choice' %}
      {% do entries.append(dbt_decisions.decisions_question_entry(name, 'choice', spec['question'], dbt_decisions.decisions_normalize_choices(spec['choices']))) %}
      {% do cols.append(dbt_decisions.databricks__bundle_get(name, 'choice', 'string') ~ ' as ' ~ name) %}
      {% if spec.get('confidence') %}{% do cols.append(dbt_decisions.databricks__bundle_get(name, 'confidence', 'double') ~ ' as ' ~ name ~ '_confidence') %}{% endif %}
    {% else %}
      {% do entries.append(dbt_decisions.decisions_question_entry(name, 'score', spec['question'], spec['criteria'])) %}
      {% do cols.append(dbt_decisions.databricks__bundle_get(name, 'score', 'double') ~ ' as ' ~ name) %}
      {% if spec.get('confidence') %}{% do cols.append(dbt_decisions.databricks__bundle_get(name, 'confidence', 'double') ~ ' as ' ~ name ~ '_confidence') %}{% endif %}
    {% endif %}
  {% endfor %}
  {% set json = '{' ~ entries | join(', ') ~ '}' %}
  {{ return('select\n    ' ~ cols | join(',\n    ') ~ '\nfrom (select __dd_i.*, ai_decide(' ~ state ~ ', ' ~ dbt_decisions.decisions_string_literal(json) ~ ') as __dd_decision from ' ~ relation ~ ' as __dd_i) as __dd_t') }}
{% endmacro %}

{% macro databricks__ai_decide_get(state, question_json, path, as_type) %}
  {{ return("variant_get(ai_decide(" ~ state ~ ", " ~ dbt_decisions.decisions_string_literal(question_json) ~ "), '$.response.answers.decision." ~ path ~ "', '" ~ as_type ~ "')") }}
{% endmacro %}

{% macro databricks__decision_probability(state, question) %}
  {{ return(dbt_decisions.databricks__ai_decide_get(state, dbt_decisions.databricks__question_json('noul', question), 'probability', 'double')) }}
{% endmacro %}

{% macro databricks__decision_choice(state, question, choices) %}
  {{ return(dbt_decisions.databricks__ai_decide_get(state, dbt_decisions.databricks__question_json('choice', question, choices), 'choice', 'string')) }}
{% endmacro %}

{% macro databricks__decision_score(state, question, criteria) %}
  {{ return(dbt_decisions.databricks__ai_decide_get(state, dbt_decisions.databricks__question_json('score', question, criteria), 'score', 'double')) }}
{% endmacro %}

{# Scalar confidence is refused on Databricks: a separate ai_decide call could describe a different answer than the label.
   decision_bundle extracts confidence from its single ai_decide variant instead (databricks__bundle_get). #}
{% macro databricks__decisions_choice_confidence(state, question, choices) %}
  {{ exceptions.raise_compiler_error("dbt_decisions: scalar confidence is not available on Databricks (a separate ai_decide call could describe a different answer than the label); use decision_bundle with 'confidence': true") }}
{% endmacro %}

{% macro databricks__decisions_score_confidence(state, question, criteria) %}
  {{ exceptions.raise_compiler_error("dbt_decisions: scalar confidence is not available on Databricks (a separate ai_decide call could describe a different answer than the label); use decision_bundle with 'confidence': true") }}
{% endmacro %}
