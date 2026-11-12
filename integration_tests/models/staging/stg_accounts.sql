select
    account_id,
    account_name,
    plan,
    seats,
    arr_usd,
    cast(renewal_date as date) as renewal_date
from {{ ref('accounts') }}
