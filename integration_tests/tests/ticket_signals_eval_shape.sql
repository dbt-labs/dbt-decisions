{# Failing row: the eval did not cover every labelled ticket, or a metric is missing or out of range.
   Never asserts that the metrics are good. #}
select *
from {{ ref('ticket_signals_eval') }}
where labelled_tickets != (select count(*) from {{ ref('ticket_labels') }})
   or topic_accuracy is null or topic_accuracy < 0 or topic_accuracy > 1
   or churn_accuracy is null or churn_accuracy < 0 or churn_accuracy > 1
   or urgency_mean_abs_error is null or urgency_mean_abs_error < 0 or urgency_mean_abs_error > 4
   or churn_true_positives + churn_missed + churn_false_alarms > labelled_tickets
