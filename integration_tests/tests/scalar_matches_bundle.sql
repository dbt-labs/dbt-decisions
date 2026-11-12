{# The scalar macros and decision_bundle must give the same answer for the same state and question.
   Tolerance only absorbs float noise. #}
select b.ticket_id, b.churn_risk, s.churn_risk as scalar_churn_risk, b.topic, s.topic as scalar_topic,
       b.urgency, s.urgency as scalar_urgency
from {{ ref('ticket_signals') }} as b
join {{ ref('scalar_signals') }} as s on b.ticket_id = s.ticket_id
where abs(b.churn_risk - s.churn_risk) > 0.0001
   or b.topic != s.topic
   or abs(b.urgency - s.urgency) > 0.0001
