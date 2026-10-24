{# dataset var may be "dataset" (project = target.database) or "project.dataset". #}
{% macro decisions_bigquery_names() %}
  {% set dataset = var('dbt_decisions_dataset', 'dbt_decisions') %}
  {% set path = dataset if '.' in dataset else target.database ~ '.' ~ dataset %}
  {{ return({'dataset': dataset, 'schema_path': path, 'function': path ~ '.decisions_ask'}) }}
{% endmacro %}

{% macro bigquery__question_json(type, instructions, criteria=none) %}
  {{ return('{' ~ dbt_decisions.decisions_question_entry('decision', type, instructions, criteria) ~ '}') }}
{% endmacro %}

{% macro bigquery__ask_call(state, questions_json) %}
  {{ return('`' ~ dbt_decisions.decisions_bigquery_names()['function'] ~ '`(to_json(' ~ state ~ '), json ' ~ dbt_decisions.decisions_string_literal(questions_json) ~ ')') }}
{% endmacro %}

{% macro bigquery__ask_get(state, question_json, path, as_type) %}
  {{ return('cast(json_value(' ~ dbt_decisions.bigquery__ask_call(state, question_json) ~ ", '$.answers.decision." ~ path ~ "') as " ~ as_type ~ ')') }}
{% endmacro %}

{% macro bigquery__decision_probability(state, question) %}
  {{ return(dbt_decisions.bigquery__ask_get(state, dbt_decisions.bigquery__question_json('noul', question), 'noul', 'float64')) }}
{% endmacro %}

{% macro bigquery__decision_choice(state, question, choices) %}
  {{ return(dbt_decisions.bigquery__ask_get(state, dbt_decisions.bigquery__question_json('choice', question, choices), 'choice', 'string')) }}
{% endmacro %}

{% macro bigquery__decision_score(state, question, criteria) %}
  {{ return(dbt_decisions.bigquery__ask_get(state, dbt_decisions.bigquery__question_json('score', question, criteria), 'score', 'float64')) }}
{% endmacro %}

{# Scalar confidence is refused on BigQuery: a separate call could describe a different answer than the label. #}
{% macro bigquery__decisions_choice_confidence(state, question, choices) %}
  {{ exceptions.raise_compiler_error("dbt_decisions: scalar confidence is not available on BigQuery (a separate decisions_ask call could describe a different answer than the label); use decision_bundle with 'confidence': true") }}
{% endmacro %}

{% macro bigquery__decisions_score_confidence(state, question, criteria) %}
  {{ exceptions.raise_compiler_error("dbt_decisions: scalar confidence is not available on BigQuery (a separate decisions_ask call could describe a different answer than the label); use decision_bundle with 'confidence': true") }}
{% endmacro %}

{% macro bigquery__bundle_get(name, field, as_type) %}
  {{ return("cast(json_value(__dd_t.__dd_decision, '$.answers." ~ name ~ "." ~ field ~ "') as " ~ as_type ~ ')') }}
{% endmacro %}

{# One decisions_ask call per row in a derived table; the outer select extracts and drops the helper column.
   NULL state: the proxy replies null, so every extracted column is NULL (no guard). #}
{% macro bigquery__decision_bundle(relation, state, questions, passthrough) %}
  {% set cols = [] %}
  {% set entries = [] %}
  {% if passthrough == '*' %}{% do cols.append('__dd_t.* except (__dd_decision)') %}{% else %}{% for c in passthrough %}{% do cols.append('__dd_t.' ~ c) %}{% endfor %}{% endif %}
  {% for name, spec in questions.items() %}
    {% if spec['type'] == 'probability' %}
      {% do entries.append(dbt_decisions.decisions_question_entry(name, 'noul', spec['question'])) %}
      {% do cols.append(dbt_decisions.bigquery__bundle_get(name, 'noul', 'float64') ~ ' as ' ~ name) %}
    {% elif spec['type'] == 'choice' %}
      {% do entries.append(dbt_decisions.decisions_question_entry(name, 'choice', spec['question'], dbt_decisions.decisions_normalize_choices(spec['choices']))) %}
      {% do cols.append(dbt_decisions.bigquery__bundle_get(name, 'choice', 'string') ~ ' as ' ~ name) %}
      {% if spec.get('confidence') %}{% do cols.append(dbt_decisions.bigquery__bundle_get(name, 'confidence', 'float64') ~ ' as ' ~ name ~ '_confidence') %}{% endif %}
    {% else %}
      {% do entries.append(dbt_decisions.decisions_question_entry(name, 'score', spec['question'], spec['criteria'])) %}
      {% do cols.append(dbt_decisions.bigquery__bundle_get(name, 'score', 'float64') ~ ' as ' ~ name) %}
      {% if spec.get('confidence') %}{% do cols.append(dbt_decisions.bigquery__bundle_get(name, 'confidence', 'float64') ~ ' as ' ~ name ~ '_confidence') %}{% endif %}
    {% endif %}
  {% endfor %}
  {% set json = '{' ~ entries | join(', ') ~ '}' %}
  {{ return('select\n    ' ~ cols | join(',\n    ') ~ '\nfrom (select __dd_i.*, ' ~ dbt_decisions.bigquery__ask_call(state, json) ~ ' as __dd_decision from ' ~ relation ~ ' as __dd_i) as __dd_t') }}
{% endmacro %}
