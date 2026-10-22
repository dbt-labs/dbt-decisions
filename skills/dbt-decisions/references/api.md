# dbt_decisions API

All macros take `state`: a SQL expression (usually a column) holding the text to judge. `question`, `choices` and `criteria` are compile-time constants, not columns. Every macro returns NULL when there is no decision. The scalar macros return a SQL expression, not a named column: add your own `as <name>` (the examples do). `decision_bundle` returns a whole SELECT and chooses its column names (see its section). Arguments are validated at compile time; errors name the macro and argument.

## decision_probability

Probability (0 to 1) that a condition is true for the text. Ask one condition per question.

```jinja
{{ dbt_decisions.decision_probability(
    state="body",
    question="Is this customer likely to churn?"
) }} as churn_probability
```

Returns a float in [0, 1]. Confidence (a `decision_bundle` option) is only for choice and score questions: the service returns no separate confidence for yes/no questions, and the probability already shows certainty (near 0 or 1 is sure, near 0.5 is unsure). To keep only confident answers, filter on the probability itself, e.g. `>= 0.8` or `<= 0.2`.

## decision_choice

Picks one label from a fixed set.

```jinja
{{ dbt_decisions.decision_choice(
    state="body",
    question="What type of problem is this?",
    choices=["billing", "technical", "other"]
) }} as topic
```

Returns one of `choices` (string). `choices` is 1 to 255 unique, non-empty strings, or a mapping label to description (a non-empty string or `none`):

```jinja
choices={"billing": "invoices, refunds, payment failures", "technical": "errors, outages", "other": none}
```

Whether descriptions are sent depends on the adapter: see `references/backends/<adapter>.md`. Where they are not sent, compiling warns and uses the labels.

## decision_score

Rates the text against an ordered list of level descriptions.

```jinja
{{ dbt_decisions.decision_score(
    state="body",
    question="How urgent is this?",
    criteria=["Not urgent: no action needed", "Low: can wait a week", "Medium: handle this week",
              "High: needs attention today", "Critical: service is down"]
) }} as urgency
```

`criteria` is 2 to 10 unique, non-blank strings, lowest level first. Returns a float on `0 .. len(criteria) - 1` (zero-based, may be fractional; 0 is the first description). There is no `min` or `max`; add an offset in SQL if you need one. Jev's own documentation reports one test where descriptive levels scored better than bare numbers (doc read 2026-10-20); the effect is unmeasured here.

## decision_bundle

Asks several questions about the same text in one query. It returns a SELECT (use it as a model body or inside `from (...)`) with the pass-through columns plus one column per question.

```jinja
{{ dbt_decisions.decision_bundle(
    relation=ref('tickets'),
    state='body',
    passthrough=['id'],
    questions={
        'churn':   {'type': 'probability', 'question': 'Is this customer likely to churn?'},
        'topic':   {'type': 'choice', 'question': 'What type of problem is this?', 'choices': ['billing', 'technical', 'other'], 'confidence': true},
        'urgency': {'type': 'score', 'question': 'How urgent is this?', 'criteria': ['Low', 'Medium', 'High'], 'confidence': true},
    }
) }}
```

Output columns, in this order:
1. The pass-through columns, with their own names (`id`). With `passthrough='*'`, every column of `relation`.
2. For each question, in the order you wrote them: a column named exactly the question's key (`churn`, `topic`, `urgency`), immediately followed by `<key>_confidence` if `'confidence': true`.

So the example returns `id`, `churn`, `topic`, `topic_confidence`, `urgency`, `urgency_confidence`. Types: probability and confidence are floats in [0, 1], a choice is a string, a score is a float on `0 .. len(criteria) - 1`. A question key that matches a pass-through column name is an error (caught at compile time for an explicit list; with `'*'` the database reports it), so list pass-through columns explicitly when in doubt.

Each question column equals the matching scalar macro on the same `state` (on Databricks it is one joint call, so answers can differ slightly).

- `passthrough`: `'*'` (default) or a list of column names to carry through.
- Question `type` is `probability`, `choice` or `score`; the other keys follow the scalar macros. `confidence: true` adds `<name>_confidence` (choice and score only).
- Question names match `[a-z_][a-z0-9_]*`, are unique, are not SQL reserved words, and do not start with `__dd_`.
- In `state`, use unqualified column names only (no `*`, aggregate, window, `--`, `/*`, `;` or `__dd_`).
- A bundle is the same interface on every warehouse but not the same cost; see your backend file.
