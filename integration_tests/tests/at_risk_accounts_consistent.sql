{# Failing rows: an account listed as at risk with no risky ticket, or with a max risk under the threshold. #}
select *
from {{ ref('at_risk_accounts') }}
where risky_tickets < 1 or max_churn_risk < {{ var('churn_risk_threshold') }}
