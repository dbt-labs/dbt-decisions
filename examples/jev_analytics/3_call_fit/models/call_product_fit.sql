select
    p.call_id,
    a.account_id,
    a.account_name,
    a.segment,
    p.fit_probability,
    p.fit_probability >= {{ var('fit_threshold', 0.8) }} as is_fit
from {{ ref('call_fit_probability') }} p
join {{ ref('accounts') }} a using (account_id)
