{# The scalar macros, with the same questions as ticket_signals.
   No scalar confidence: Databricks refuses it (use decision_bundle with 'confidence': true). #}
select
    ticket_id,
    {{ dbt_decisions.decision_noul(
        state='ticket_text',
        question='Is this customer signalling they might cancel, downgrade, or switch to a competitor?'
    ) }} as churn_risk,
    {{ dbt_decisions.decision_choice(
        state='ticket_text',
        question='What is this support ticket mainly about?',
        choices=['billing', 'bug', 'feature_request', 'how_to', 'account_access',
                 'security_privacy', 'renewal_or_cancellation', 'other']
    ) }} as topic,
    {{ dbt_decisions.decision_score(
        state='ticket_text',
        question='How urgent is this ticket for the support team?',
        criteria=[
            'None: a thank-you or FYI, no action needed',
            'Low: a question or request that can wait a week',
            'Medium: something is broken or blocked, handle this week',
            'High: blocking work for many users or tied to a near-term deadline, handle today',
            'Critical: security, privacy or legal exposure, or a customer escalating to executives'
        ]
    ) }} as urgency
from {{ ref('stg_support_tickets') }}
