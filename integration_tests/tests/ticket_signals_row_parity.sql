{# Failing row: the bundle dropped or duplicated tickets. #}
select s.n as bundle_rows, t.n as ticket_rows
from (select count(*) as n from {{ ref('ticket_signals') }}) as s
cross join (select count(*) as n from {{ ref('stg_support_tickets') }}) as t
where s.n != t.n
