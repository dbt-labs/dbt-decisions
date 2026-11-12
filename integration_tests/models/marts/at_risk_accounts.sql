{# Plain SQL on top of the stored decisions: changing the threshold costs no new backend calls. #}
select
    a.account_id,
    a.account_name,
    a.plan,
    a.arr_usd,
    a.renewal_date,
    count(*) as risky_tickets,
    max(s.churn_risk) as max_churn_risk,
    max(s.created_at) as last_risky_ticket_at
from {{ ref('ticket_signals') }} as s
join {{ ref('stg_accounts') }} as a on s.account_id = a.account_id
where s.churn_risk >= {{ var('churn_risk_threshold') }}
group by a.account_id, a.account_name, a.plan, a.arr_usd, a.renewal_date
