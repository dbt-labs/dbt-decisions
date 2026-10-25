# PostgreSQL

- Engine: `pgjev` extension. Install it and set `jev.api_url`; needs an API key.
- `decision_bundle`: one request per question per row for a text column. Bundle and scalar results are identical by construction.
- Confidence: `decision_bundle` confidence is free (pgjev cache, no extra request) and always matches its label.
- NULL state: NULL result; never sent (the macros guard the call).
- Descriptions: `decision_score` criteria are sent as the level strings. `decision_choice` sends labels only: a `choices` mapping with a description gives a compile-time warning and the description is dropped (pgjev source at the pinned commit `e3450d4`, read 2026-10-20; unmeasured: that the installed pgjev matches that source, the warning under dbt Fusion, and any effect of descriptions on answer quality).
