{# decision_bundle: all three question types over one state, one backend call per row, with confidence. #}
{{ dbt_decisions.decision_bundle(
    relation=ref('stg_support_tickets'),
    state='ticket_text',
    passthrough=['ticket_id', 'account_id', 'created_at', 'channel', 'subject'],
    questions={
        'churn_risk': {
            'type': 'noul',
            'question': 'Is this customer signalling they might cancel, downgrade, or switch to a competitor?'
        },
        'topic': {
            'type': 'choice',
            'question': 'What is this support ticket mainly about?',
            'choices': ['billing', 'bug', 'feature_request', 'how_to', 'account_access',
                        'security_privacy', 'renewal_or_cancellation', 'other'],
            'confidence': true
        },
        'urgency': {
            'type': 'score',
            'question': 'How urgent is this ticket for the support team?',
            'criteria': [
                'None: a thank-you or FYI, no action needed',
                'Low: a question or request that can wait a week',
                'Medium: something is broken or blocked, handle this week',
                'High: blocking work for many users or tied to a near-term deadline, handle today',
                'Critical: security, privacy or legal exposure, or a customer escalating to executives'
            ],
            'confidence': true
        }
    }
) }}
