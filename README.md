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

```sql
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

### Supported databases

- BigQuery (dbt v1)
- Databricks (dbt v1)
- Snowflake (dbt v1 and dbt v2; needs dbt Core 1.11+)

### Issues blocking dbt v2 support

For databases not currently working with dbt v2, see below for the blocking issues:

#### BigQuery
  - https://github.com/dbt-labs/dbt/issues/16875
    - Workaround: `dbt build --target bigquery --exclude-resource-type function`

#### Databricks
  - https://github.com/dbt-labs/dbt/issues/16874
    - Workaround: `dbt build --target databricks --exclude-resource-type seed`
  - https://github.com/dbt-labs/dbt/issues/16875
    - Workaround: `dbt build --target databricks --exclude-resource-type function`

### BigQuery

A remote function `decisions_ask` calls a small Cloud Run proxy (`bigquery_proxy/`) that forwards to the Jev service. You deploy the proxy and create the connection yourself; setup creates only the dataset and the function. For package users the proxy path is `dbt_packages/dbt_decisions/bigquery_proxy` (after executing `dbt deps`, of course!).

Note: `gcloud secrets create` needs `--project` if your gcloud project differs, and the key must reach `--data-file=-` on one line. `--no-allow-unauthenticated` plus the invoker role is the only access control (the proxy does not check the caller's token).

```bash
gcloud services enable run.googleapis.com secretmanager.googleapis.com bigquery.googleapis.com bigqueryconnection.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com
```

Create the secret yourself, reading the key without echoing it:
```bash
read -rs TYPESAFE_API_KEY && printf %s "$TYPESAFE_API_KEY" | gcloud secrets create typesafe-api-key --data-file=- && unset TYPESAFE_API_KEY
```

Find `<RUN_SERVICE_ACCOUNT>` (empty means the default compute service account) with:
```bash
gcloud run services describe decisions-proxy --region <REGION> --format='value(spec.template.spec.serviceAccountName)'
```

Find `<CONNECTION_SA>` (field `cloudResource.serviceAccountId`) with:
```bash
bq show --connection --format=json <PROJECT>.<LOCATION>.decisions_conn
```

```bash
gcloud secrets add-iam-policy-binding typesafe-api-key --member=serviceAccount:<RUN_SERVICE_ACCOUNT> --role=roles/secretmanager.secretAccessor
gcloud run deploy decisions-proxy --source bigquery_proxy --region <REGION> --no-allow-unauthenticated --max-instances 3 --timeout 300 --concurrency 4 --set-secrets TYPESAFE_API_KEY=typesafe-api-key:latest
bq mk --connection --location=<LOCATION> --connection_type=CLOUD_RESOURCE decisions_conn
```

Grant the connection's service account run.invoker on the service (wait about 60 s):
```bash
gcloud run services add-iam-policy-binding decisions-proxy --region <REGION> --member=serviceAccount:<CONNECTION_SA> --role=roles/run.invoker
dbt run-operation dbt_decisions.setup --vars '{dbt_decisions_endpoint: <SERVICE_URL>, dbt_decisions_connection: <PROJECT>.<LOCATION>.decisions_conn}'
```

### Databricks

Uses the built-in [`ai_decide`](https://docs.databricks.com/aws/en/sql/language-manual/functions/ai_decide) function. Requirements: the AI Functions Beta enabled for the workspace, a supported region, a SQL warehouse that is **not** SQL Classic (Pro or Serverless), DBR 15.4+ (18.2+ recommended). There is nothing to install; `doctor` probes `ai_decide` and reports the likely cause if it is unavailable.

### Snowflake

1. Add this to your `dbt_project.yml`:

   ```yaml
   dispatch:
     - macro_namespace: dbt
       search_order: ['dbt_decisions', 'dbt']
   ```

  Otherwise, the package's override of `snowflake__get_function_python_options` that attaches the integration and secret to the UDF will be ignored.

2. Create the secret for the Jev API key:

   ```sql
   create secret <db>.<schema>.jev_api_key type = generic_string secret_string = '<your TypeSafe key>';
   ```

   The default is `<target.database>.<target.schema>.jev_api_key`. A secret elsewhere or under another name needs the following in your `dbt_project.yml`:

    ```yaml
    vars:
      dbt_decisions_secret: <db>.<schema>.<name>
    ```

3. Create the network rule that allows egress to `api.typesafe.ai` and external access integration. Either let `setup` create them when missing:

   ```bash
   dbt run-operation dbt_decisions.setup
   ```
   or create them yourself.

   You can reuse existing objects by setting the applicable `vars` in your `dbt_project.yml`:

    ```yaml
    vars:
      dbt_decisions_network_rule: jev_egress
      dbt_decisions_integration: dbt_decisions_it_jev_access
    ```


4. `dbt build --select "resource_type:function"` will create the `decisions_ask_json` and `decisions_ask` UDFs in your target's schema.

Grants: the role that builds the function needs `READ` on the secret, `USAGE` on the secret's schema and `USAGE` on the integration; creating the integration needs `CREATE INTEGRATION` on the account. `dbt run-operation dbt_decisions.doctor` will report if there is a missing function, integration or secret.

To opt out of these UDFs, set this in your `dbt_project.yml`:

```yaml
functions:
  dbt_decisions:
    snowflake:
      +enabled: false
```
