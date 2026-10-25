{# Agreement with the hand-assigned expected_fit labels (confusion counts). #}
select
    c.expected_fit,
    f.is_fit as predicted_fit,
    count(*) as calls
from {{ ref('call_product_fit') }} f
join {{ ref('sales_calls') }} c using (call_id)
group by 1, 2
order by 1 desc, 2 desc
