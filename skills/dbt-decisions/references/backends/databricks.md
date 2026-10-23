# Databricks

- Engine: built-in `ai_decide` (AI Functions Beta). Needs a Pro or Serverless SQL warehouse, not SQL Classic. No setup.
- `decision_bundle`: one call per row for all questions (cheapest bundle). Answers may differ from separate scalar macros, because the bundle is one joint call.
- Confidence: `decision_bundle` confidence comes from the same single `ai_decide` call as the label, so they always match. Scalar confidence is not available on Databricks.
- NULL state: NULL result.
- In a bundle, do not qualify columns in `state` with the relation's name or alias.
- Billed as AI function usage. Rate limits unknown.
