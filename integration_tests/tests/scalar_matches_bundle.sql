{# The scalar macros and decision_bundle must give the same answer for the same state and question, but only
   where both read one cached answer (DuckDB and Postgres). On Databricks, Snowflake and BigQuery the bundle makes
   one call for all questions and each scalar macro makes its own, and a decision model's answers differ a little
   between prompts (measured on Databricks: churn up to 0.38 apart, 8 of 80 topics differ). That is the reason scalar
   confidence is refused there, so no match is asserted. Tolerance only absorbs float noise. #}
select b.ticket_id, b.churn_risk, s.churn_risk as scalar_churn_risk, b.topic, s.topic as scalar_topic,
       b.urgency, s.urgency as scalar_urgency
from {{ ref('ticket_signals') }} as b
join {{ ref('scalar_signals') }} as s on b.ticket_id = s.ticket_id
where {% if target.type in ['duckdb', 'postgres'] %}
      abs(b.churn_risk - s.churn_risk) > 0.0001
   or b.topic != s.topic
   or abs(b.urgency - s.urgency) > 0.0001
      {% else %}1 = 0{% endif %}
