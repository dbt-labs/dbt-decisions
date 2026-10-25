{{ config(pre_hook="{{ jev_call_fit.load_jev() }}") }}
{# Use case 3 (SYNTHETIC data): store the raw probability once; the threshold is applied downstream. #}
select
    call_id,
    account_id,
    {{ dbt_decisions.decision_probability(
        state="transcript",
        question="Does the customer describe a need to analyze many customer conversations (calls, chats or tickets) at scale?"
    ) }} as fit_probability
from {{ ref('sales_calls') }}
