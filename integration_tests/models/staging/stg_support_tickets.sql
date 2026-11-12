select
    ticket_id,
    account_id,
    created_at,
    channel,
    subject,
    body,
    -- The text a decision model will judge: subject and body together.
    {{ dbt.concat(['subject', "': '", 'body']) }} as ticket_text
from {{ ref('support_tickets') }}
