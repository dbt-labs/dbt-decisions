{# Typed output guarantees shape, not truth: compare the decision columns against the hand-labelled tickets.
   The tests only check that these metrics exist and are in range, never that they are good. #}
with joined as (
    select
        s.ticket_id,
        s.topic,
        l.label_topic,
        s.churn_risk >= {{ var('churn_risk_threshold') }} as predicted_churn_risk,
        l.label_churn_risk,
        round(s.urgency) as predicted_urgency,
        l.label_urgency
    from {{ ref('ticket_signals') }} as s
    join {{ ref('ticket_labels') }} as l on s.ticket_id = l.ticket_id
)

select
    count(*) as labelled_tickets,
    avg(case when topic = label_topic then 1.0 else 0.0 end) as topic_accuracy,
    avg(case when predicted_churn_risk = label_churn_risk then 1.0 else 0.0 end) as churn_accuracy,
    sum(case when predicted_churn_risk and label_churn_risk then 1 else 0 end) as churn_true_positives,
    sum(case when not predicted_churn_risk and label_churn_risk then 1 else 0 end) as churn_missed,
    sum(case when predicted_churn_risk and not label_churn_risk then 1 else 0 end) as churn_false_alarms,
    avg(abs(predicted_urgency - label_urgency)) as urgency_mean_abs_error
from joined
