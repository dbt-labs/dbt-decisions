# DuckDB

- Engine: `jev` community extension. Works only on DuckDB 1.5.5 or 1.5.6. Load it in a pre-hook or the profile; API key in env `TYPESAFE_API_KEY`.
- Confidence: `decision_bundle` confidence is free (cached, no extra request) and always matches its label.
- NULL state: NULL result; never sent.
- Descriptions: `decision_score` criteria are sent as the level strings. `decision_choice` sends labels only: a `choices` mapping with a description gives a compile-time warning and the description is dropped.