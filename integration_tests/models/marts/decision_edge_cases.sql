{{ dbt_decisions.decision_bundle(
    relation=ref('edge_case_states'),
    state='state_text',
    passthrough=['case_id', 'case_name'],
    questions={
        'is_cancel': {'type': 'noul', 'question': 'Is this a cancellation request?'},
        'topic': {
            'type': 'choice',
            'question': 'What is this mainly about?',
            'choices': ['billing', 'bug', 'other'],
            'confidence': true
        },
        'urgency': {
            'type': 'score',
            'question': 'How urgent is this?',
            'criteria': ['Low: can wait', 'Medium: this week', 'High: today'],
            'confidence': true
        }
    }
) }}
