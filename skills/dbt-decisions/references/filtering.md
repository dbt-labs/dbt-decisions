# Filtering on certainty

Decide once and store the result. Filter in a downstream model, so changing a threshold makes no new API calls.

## Labels and scores: filter on the `_confidence` column

Model `tickets_topic.sql` (makes the API calls). Use `decision_bundle` with `'confidence': true` so the label and its confidence always come from the same answer:

```sql
{{ dbt_decisions.decision_bundle(
    relation=ref('tickets'),
    state='body',
    passthrough=['id', 'body'],
    questions={
        'topic': {
            'type': 'choice',
            'question': 'What type of problem is this?',
            'choices': ['billing', 'technical', 'other'],
            'confidence': true,
        },
    }
) }}
```

Model `tickets_topic_confident.sql` (plain SQL, no API calls):

```sql
select id, body, topic
from {{ ref('tickets_topic') }}
where topic_confidence >= {{ var('min_confidence', 0.8) }}
```

The same pattern works for scores: a `score` question with `criteria` and `'confidence': true`.

## Yes/no: filter on the probability itself

```sql
-- likely churners
select id from {{ ref('tickets_churn') }} where churn_probability >= 0.8
-- confidently not churners
select id from {{ ref('tickets_churn') }} where churn_probability <= 0.2
```

Rows between the two thresholds are the uncertain ones; review those by hand or treat them as unknown.

Tune each threshold on your own labelled rows: compare the filtered rows with about 30 you labelled by hand.
