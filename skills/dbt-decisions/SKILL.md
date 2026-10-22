---
name: dbt-decisions
description: "Use when adding semantic judgments to dbt models (is this text about X, which category is it, how urgent is it, how sure is the model) with the dbt_decisions package: decision_probability, decision_choice, decision_score, and decision_bundle (with optional confidence)."
---

# Using dbt_decisions

Syntax: `references/api.md`. Read it before writing models.
Warehouse caveats and cost: read `references/backends/<adapter>.md` for your target (`target.type`). No file for it, or unsure? Run `dbt run-operation dbt_decisions.doctor`; it says whether the adapter is supported and what is missing.

## Choose the macro
- True or false? `decision_probability` (one condition per question).
- One label from a fixed set? `decision_choice`.
- Degree on an ordered scale? `decision_score` with a `criteria` list of level descriptions (result is zero-based).

Common shapes in analytics:
- Classification (intent, topic, risk type): `decision_choice`.
- Detection (spam, fraud, urgency, sensitive data) and verification (policy violation, unsupported claim): `decision_probability`.
- Scoring (severity, quality, frustration) and ranking (sort by the score): `decision_score`.
- Routing: `decision_choice`, then a plain SQL `case` on the label.
- ML features (purchase intent, churn signals): one decision column per signal, usually in a `decision_bundle`.
- Extraction: only for fields with a known set of values (`decision_choice`). Free-text extraction is not supported.
- Search, retrieval and semantic ranking over many items: not supported by this package.

## Filter on certainty
Examples: `references/filtering.md`.
- Confidence is how concentrated the answer is, not whether it is right. Thresholds like 0.8 are starting points: tune them on your own labelled rows.
- Labels and scores: ask for the confidence in the same `decision_bundle` (`'confidence': true`) and filter on it (e.g. `>= 0.8`).
- Yes/no: confidence is only for choice and score questions. The service returns no separate confidence for yes/no questions, and the probability already shows certainty (near 0 or 1 is sure, near 0.5 is unsure). Filter on the probability itself, e.g. `>= 0.8` or `<= 0.2`.

## Rules
- Keep exact logic (regex, joins, arithmetic, lookups) in SQL. Use a decision only where meaning matters.
- Several questions on the same text: use `decision_bundle`. Same interface everywhere, not the same cost (see your warehouse's file in `references/backends/`).
- Filter rows with plain SQL first; every row that reaches a macro can cost an API call.
- Typed output guarantees shape, not truth. Compare a new column with about 30 rows you labelled by hand before trusting it.
- `state` is sent to a remote service. Send the minimum text, and never secrets or personal data you would not send to a vendor.
- Develop on a small `limit`; real calls cost money.

## Scale and cost
- Cost is rows x questions x text length. Per-row costs are in `references/backends/<adapter>.md`; treat them as orders of magnitude, not quotes.
- Ten rows: just run it. Thousands: filter first, then store results. Millions or more: decide on a sample or on distinct texts only; do not decide every row on every run.
- Only `incremental` avoids repeat calls: a `table` rebuilds, and a `view` re-decides on every query. Use `incremental` (new rows only) for decision models beyond experiments.
- Rate limits and very large scale are unmeasured. Start small, watch errors and retries, then scale.
