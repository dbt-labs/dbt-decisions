# dbt_decisions

This dbt package enables using [`jev`](https://typesafe.ai/blog/introducing-system-one-models-and-jev)-class decision models inside SQL.

## Quick intro to decision models

Most of us are familiar with chat sessions with AI: you ask an unstructured question in free text, and it gives you unstructured, free text in reply -- infinite possibilities on both ends of the conversation.

In contrast, a decision model responds to **constrained** and **structured** questions with a **simple** and **structured** answer. Types of question-answers:
- a probability between 0% and 100% for a yes/no question
- one choice from a fixed, unordered list
- one selection from a fixed, ordered scale

### Examples

- Is today a garbage day `[0.0-1.0]`? **96%**
- What is the last letter of this sentence `[A-Z]`? **E**
- Which log level is best for fine-grained diagnostic details used by developers to troubleshoot and test code `[INFO, WARN, DEBUG]`? **DEBUG**

## Installing the Package
Include the following in your `packages.yml`

> [Read the dbt docs](https://docs.getdbt.com/docs/build/packages#how-do-i-specify-a-package) for more information on installing packages.

```yaml
packages:
  - git: "https://github.com/dbt-labs/dbt-decisions.git"
    revision: main
```

## Macros

```jinja
{{ dbt_decisions.decision_probability(
    state="support_ticket",
    question="Is this customer likely to churn?"
) }}                                   {# float in [0, 1] #}

{{ dbt_decisions.decision_choice(
    state="support_ticket",
    question="What type of problem is this?",
    choices=["billing", "technical", "sales", "other"]
) }}                                   {# one of the choices (string) #}

{{ dbt_decisions.decision_choice(
    state="support_ticket",
    question="What type of problem is this?",
    choices={
        "billing": "invoices, refunds, payment failures",
        "technical": "errors, outages, how-to questions",
        "other": none
    }
) }}                                   {# same, with a description per choice #}

{{ dbt_decisions.decision_score(
    state="support_ticket",
    question="How urgent is this issue?",
    criteria=["Not urgent: no action needed", "Low: can wait a week", "Medium: handle this week",
              "High: needs attention today", "Critical: service is down"]
) }}                                   {# float in [0, 4], zero-based #}
```

### Usage example

```sql
select id, {{ dbt_decisions.decision_probability(state="support_ticket", question="Is this customer likely to churn?") }} as churn_probability
from {{ ref('support_tickets') }}
```
