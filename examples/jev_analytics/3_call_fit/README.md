# 3. Sales calls: which conversations match the use cases we serve?

[Blog use case 3](https://motherduck.com/blog/jev-analytics-use-cases/). `decision_probability` asks one yes/no question of each call snippet ("does the customer describe a need to analyze many customer conversations at scale?") and stores the probability once. The threshold (`fit_threshold`, default 0.8) is applied in a separate model after a join to `accounts`, so changing it costs no new API calls.

## Synthetic seed data

| Seed | What it does |
|---|---|
| `accounts` | 10 fake customers |
| `accounts` | 30 fake snippets with a hand-assigned `expected_fit` |

## Models

| Model | What it does |
|---|---|
| `call_fit_probability` | One `decision_probability` per call, stored |
| `call_product_fit` | Joins `accounts`; `is_fit = fit_probability >= fit_threshold`: the review shortlist |
| `call_product_fit_eval` | Confusion counts of `is_fit` against the hand-assigned `expected_fit` |

## Initial setup

Install the package and load the synthetic seed data.

```shell
dbt deps
dbt seed --target ADAPTER_NAME
```

## Run it

Build all the models, inluding those using `dbt-decisions` macros.

Cost: one API call per call snippet, 30 in total.

For `ADAPTER_NAME` in duckdb, postgres, bigquery, databricks:
```shell
dbt build --target ADAPTER_NAME --exclude-resource-type function seed
```

For Snowflake:
```shell
dbt build --target snowflake --exclude-resource-type seed
```

### Output

Look at the results, comparing to the hand labels:

```bash
dbt show --inline "select * from {{ ref('call_product_fit_eval') }}"
dbt show --inline "select call_id, fit_probability from {{ ref('call_fit_probability') }} order by fit_probability desc"
```
