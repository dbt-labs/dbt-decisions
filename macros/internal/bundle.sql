{% macro decisions_bundle_allowed_keys(type) %}
  {% if type == 'probability' %}{{ return(['type', 'question']) }}{% endif %}
  {% if type == 'choice' %}{{ return(['type', 'question', 'choices', 'confidence']) }}{% endif %}
  {{ return(['type', 'question', 'criteria', 'confidence']) }}
{% endmacro %}

{# Reserved words (a best-effort union across the supported SQL dialects, not exhaustive: a name missing here fails at run time in the warehouse). Output column names are emitted unquoted. #}
{% macro decisions_bundle_reserved_words() %}
  {{ return(['all', 'and', 'any', 'as', 'asc', 'between', 'by', 'case', 'cast', 'check', 'column', 'constraint', 'create', 'cross', 'current_date', 'current_time', 'current_timestamp', 'current_user', 'default', 'desc', 'distinct', 'do', 'else', 'end', 'except', 'exists', 'false', 'fetch', 'for', 'foreign', 'from', 'full', 'grant', 'group', 'having', 'in', 'initially', 'inner', 'intersect', 'into', 'is', 'join', 'leading', 'left', 'like', 'limit', 'natural', 'not', 'null', 'offset', 'on', 'only', 'or', 'order', 'outer', 'placing', 'primary', 'references', 'returning', 'right', 'select', 'session_user', 'some', 'symmetric', 'table', 'then', 'to', 'trailing', 'true', 'union', 'unique', 'user', 'using', 'variadic', 'when', 'where', 'window', 'with', 'array', 'analyse', 'analyze', 'asymmetric', 'both', 'collate', 'deferrable', 'lateral', 'localtime', 'localtimestamp', 'authorization', 'binary', 'concurrently', 'freeze', 'ilike', 'isnull', 'notnull', 'overlaps', 'similar', 'tablesample', 'verbose', 'anti', 'semi', 'minus', 'qualify', 'pivot', 'unpivot', 'struct', 'map', 'rlike']) }}
{% endmacro %}

{# `relation` must be a plain relation, CTE name or parenthesised subquery WITHOUT its own alias (the macro aliases it as __dd_t).
   passthrough='*' cannot be checked for column-name clashes at compile time: a question named like a source column
   errors at run time (duplicate column). With a passthrough list, clashes are caught here. passthrough=[] yields question columns only. #}
{% macro decisions_validate_bundle(relation, state, questions, passthrough) %}
  {% set mn = 'decision_bundle' %}
  {% if relation is not string or (relation | trim) == '' or (relation | trim) == 'None' or '--' in relation or '/*' in relation or ';' in relation %}
    {{ dbt_decisions.decisions_fail(mn, 'relation', 'must be a non-empty relation (ref(...), a CTE name or a parenthesised subquery without its own alias, and no --, /* or ;)') }}
  {% endif %}
  {% do dbt_decisions.decisions_validate_state(state, mn) %}
  {% if '__dd_' in state or '--' in state or '/*' in state or ';' in state %}
    {{ dbt_decisions.decisions_fail(mn, 'state', 'must not contain the reserved prefix __dd_, --, /* or ; (it is embedded in a generated query; reference the relation columns unqualified, no *, aggregates or window functions)') }}
  {% endif %}
  {% if questions is not mapping or (questions | length) == 0 %}
    {{ dbt_decisions.decisions_fail(mn, 'questions', 'must be a non-empty mapping of output column name to question spec') }}
  {% endif %}
  {% if passthrough is string %}
    {% if passthrough != '*' %}
      {{ dbt_decisions.decisions_fail(mn, 'passthrough', "must be '*' or a list of column names") }}
    {% endif %}
  {% elif passthrough is not iterable or passthrough is mapping %}
    {{ dbt_decisions.decisions_fail(mn, 'passthrough', "must be '*' or a list of column names") }}
  {% else %}
    {% for c in passthrough %}
      {% if c is not string or not modules.re.match('^[A-Za-z_][A-Za-z0-9_]*$', c) %}
        {{ dbt_decisions.decisions_fail(mn, 'passthrough', 'column names must be plain identifiers, got ' ~ c) }}
      {% endif %}
      {% if (c | lower).startswith('__dd_') %}
        {{ dbt_decisions.decisions_fail(mn, 'passthrough', "column names must not start with the reserved prefix __dd_, got '" ~ c ~ "'") }}
      {% endif %}
    {% endfor %}
  {% endif %}
  {% set outputs = [] %}
  {% set pass_lower = [] %}
  {% if passthrough is not string and passthrough is iterable and passthrough is not mapping %}
    {% for c in passthrough %}
      {% if (c | string | lower) in pass_lower %}
        {{ dbt_decisions.decisions_fail(mn, 'passthrough', "duplicate output column '" ~ c ~ "' (passthrough)") }}
      {% endif %}
      {% do pass_lower.append(c | string | lower) %}
      {% do outputs.append(c | string | lower) %}
    {% endfor %}
  {% endif %}
  {% for name, spec in questions.items() %}
    {% if name is not string or not modules.re.match('^[a-z_][a-z0-9_]*$', name) %}
      {{ dbt_decisions.decisions_fail(mn, 'questions', "output column names must be lowercase identifiers (a-z, 0-9, _), got '" ~ name ~ "'") }}
    {% endif %}
    {% if name in dbt_decisions.decisions_bundle_reserved_words() %}
      {{ dbt_decisions.decisions_fail(mn, 'questions', "output column '" ~ name ~ "' is a reserved SQL word; choose another name") }}
    {% endif %}
    {% if name.startswith('__dd_') %}
      {{ dbt_decisions.decisions_fail(mn, 'questions', "output column names must not start with the reserved prefix __dd_, got '" ~ name ~ "'") }}
    {% endif %}
    {% if spec is not mapping %}
      {{ dbt_decisions.decisions_fail(mn, 'questions', "question '" ~ name ~ "' must be a mapping") }}
    {% endif %}
    {% set t = spec.get('type') %}
    {% if t not in ['probability', 'choice', 'score'] %}
      {{ dbt_decisions.decisions_fail(mn, 'questions', "question '" ~ name ~ "': type must be probability, choice or score, got " ~ t) }}
    {% endif %}
    {% set allowed = dbt_decisions.decisions_bundle_allowed_keys(t) %}
    {% for k in spec.keys() %}
      {% if k not in allowed %}
        {{ dbt_decisions.decisions_fail(mn, 'questions', "question '" ~ name ~ "': unknown key '" ~ k ~ "' for type " ~ t ~ " (allowed: " ~ allowed | join(', ') ~ ")") }}
      {% endif %}
    {% endfor %}
    {% do dbt_decisions.decisions_validate_question(spec.get('question'), mn ~ " question '" ~ name ~ "'") %}
    {% if t == 'choice' %}
      {% do dbt_decisions.decisions_validate_choices(spec.get('choices'), mn ~ " question '" ~ name ~ "'") %}
    {% elif t == 'score' %}
      {% do dbt_decisions.decisions_validate_criteria(spec.get('criteria'), mn ~ " question '" ~ name ~ "'") %}
    {% endif %}
    {% set conf = spec.get('confidence', false) %}
    {% if conf is not boolean %}
      {{ dbt_decisions.decisions_fail(mn, 'questions', "question '" ~ name ~ "': confidence must be true or false") }}
    {% endif %}
    {% if conf and t == 'probability' %}
      {{ dbt_decisions.decisions_fail(mn, 'questions', "question '" ~ name ~ "': confidence is only available for choice and score questions (a probability is already the answer)") }}
    {% endif %}
    {% for out in ([name] + ([name ~ '_confidence'] if conf else [])) %}
      {% if out in pass_lower %}
        {{ dbt_decisions.decisions_fail(mn, 'questions', "duplicate output column '" ~ out ~ "' (passthrough and question)") }}
      {% endif %}
      {% if out in outputs %}
        {{ dbt_decisions.decisions_fail(mn, 'questions', "output column '" ~ out ~ "' collides with another question's column") }}
      {% endif %}
      {% do outputs.append(out) %}
    {% endfor %}
  {% endfor %}
{% endmacro %}

{# Why the scalar confidence macros are safe here: where the label and its confidence in one query reuse one cached answer
   (same state expression, evaluated once via the lateral __dd_state, and same question/choices, so same cache key),
   the pair always matches. An adapter where a scalar confidence would be a separate call that could describe a different
   answer does not use this expansion: its scalar confidence macros raise and its bundle extracts confidence from a single call. #}
{# Shared expansion for adapters whose scalar macros are cache-backed: the state is evaluated once in a lateral subquery;
   each question is the corresponding scalar macro over __dd_s.__dd_state (so each adapter's NULL handling and escaping come for free). #}
{% macro decisions_bundle_scalar_select(relation, state, questions, passthrough) %}
  {% set cols = [] %}
  {% if passthrough == '*' %}{% do cols.append('__dd_t.*') %}{% else %}{% for c in passthrough %}{% do cols.append('__dd_t.' ~ c) %}{% endfor %}{% endif %}
  {% for name, spec in questions.items() %}
    {% if spec['type'] == 'probability' %}
      {% do cols.append(dbt_decisions.decision_probability('__dd_s.__dd_state', spec['question']) ~ ' as ' ~ name) %}
    {% elif spec['type'] == 'choice' %}
      {% set norm = dbt_decisions.decisions_normalize_choices(spec['choices']) %}
      {% do cols.append(dbt_decisions.decision_choice('__dd_s.__dd_state', spec['question'], norm) ~ ' as ' ~ name) %}
      {% if spec.get('confidence') %}
        {% do cols.append(dbt_decisions.decisions_choice_confidence('__dd_s.__dd_state', spec['question'], norm) ~ ' as ' ~ name ~ '_confidence') %}
      {% endif %}
    {% else %}
      {% do cols.append(dbt_decisions.decision_score('__dd_s.__dd_state', spec['question'], spec['criteria']) ~ ' as ' ~ name) %}
      {% if spec.get('confidence') %}
        {% do cols.append(dbt_decisions.decisions_score_confidence('__dd_s.__dd_state', spec['question'], spec['criteria']) ~ ' as ' ~ name ~ '_confidence') %}
      {% endif %}
    {% endif %}
  {% endfor %}
  {{ return('select\n    ' ~ cols | join(',\n    ') ~ '\nfrom ' ~ relation ~ ' as __dd_t\ncross join lateral (select ' ~ state ~ ' as __dd_state) as __dd_s') }}
{% endmacro %}

{# Internal: not public API. Use decision_bundle with 'confidence': true. #}
{% macro decisions_choice_confidence(state, question, choices) %}
  {% do dbt_decisions.decisions_validate_state(state, 'decisions_choice_confidence') %}
  {% do dbt_decisions.decisions_validate_question(question, 'decisions_choice_confidence') %}
  {% do dbt_decisions.decisions_validate_choices(choices, 'decisions_choice_confidence') %}
  {{ return(adapter.dispatch('decisions_choice_confidence', 'dbt_decisions')(state, question, dbt_decisions.decisions_normalize_choices(choices))) }}
{% endmacro %}

{% macro default__decisions_choice_confidence(state, question, choices) %}{{ dbt_decisions.decisions_unsupported() }}{% endmacro %}

{% macro decisions_score_confidence(state, question, criteria) %}
  {% do dbt_decisions.decisions_validate_state(state, 'decisions_score_confidence') %}
  {% do dbt_decisions.decisions_validate_question(question, 'decisions_score_confidence') %}
  {% do dbt_decisions.decisions_validate_criteria(criteria, 'decisions_score_confidence') %}
  {{ return(adapter.dispatch('decisions_score_confidence', 'dbt_decisions')(state, question, criteria)) }}
{% endmacro %}

{% macro default__decisions_score_confidence(state, question, criteria) %}{{ dbt_decisions.decisions_unsupported() }}{% endmacro %}
