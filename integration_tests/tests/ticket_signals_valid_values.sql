{# Failing rows: any decision column outside the range its question type promises. #}
select ticket_id, churn_risk, topic_confidence, urgency, urgency_confidence
from {{ ref('ticket_signals') }}
where churn_risk < 0 or churn_risk > 1
   or topic_confidence < 0 or topic_confidence > 1
   or urgency < 0 or urgency > 4
   or urgency_confidence < 0 or urgency_confidence > 1
   or topic_confidence is null
   or urgency_confidence is null
