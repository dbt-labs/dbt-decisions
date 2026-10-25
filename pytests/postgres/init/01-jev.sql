-- Runs once at first start (docker-entrypoint-initdb.d), connected to POSTGRES_DB (dbt) as the superuser.
CREATE EXTENSION jev CASCADE;
-- Database-level, so every session (dbt, psql) uses the mock. The Postgres live smoke test removes this
-- with `ALTER DATABASE dbt RESET jev.api_url` to reach the real endpoint.
-- No jev.api_key: pgjev requires a key only for *.typesafe.ai hosts.
ALTER DATABASE dbt SET jev.api_url = 'http://mock:8765/local/v1/systemone';
-- Small batches so a 45-row table must be split into several requests.
ALTER DATABASE dbt SET jev.batch_size = 20;
