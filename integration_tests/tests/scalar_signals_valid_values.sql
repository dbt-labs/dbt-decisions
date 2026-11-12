{# Failing rows: a scalar macro answer outside the range or choices its question type promises.
   Not compared with ticket_signals: the bundle is one ai_decide call and each scalar macro is its own,
   and a decision model's answers differ a little between prompts (measured: churn up to 0.38 apart). #}
select ticket_id, churn_risk, topic, urgency
from {{ ref('scalar_signals') }}
where churn_risk is null or churn_risk < 0 or churn_risk > 1
   or topic is null
   or topic not in ('billing', 'bug', 'feature_request', 'how_to', 'account_access',
                    'security_privacy', 'renewal_or_cancellation', 'other')
   or urgency is null or urgency < 0 or urgency > 4
