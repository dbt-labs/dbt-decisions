{# Failing rows: a NULL state must give NULL in every output column; every other state (including the empty
   string, quotes, backslashes, newlines and non-ASCII text) must be answered, in range. #}
select *
from {{ ref('decision_edge_cases') }}
where (case_name = 'null_state'
       and (is_cancel is not null or topic is not null or topic_confidence is not null
            or urgency is not null or urgency_confidence is not null))
   or (case_name != 'null_state'
       and (is_cancel is null or is_cancel < 0 or is_cancel > 1
            or topic is null or topic not in ('billing', 'bug', 'other')
            or topic_confidence is null or topic_confidence < 0 or topic_confidence > 1
            or urgency is null or urgency < 0 or urgency > 2
            or urgency_confidence is null or urgency_confidence < 0 or urgency_confidence > 1))
