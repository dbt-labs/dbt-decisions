# Postgres + pgjev + mock harness

## Mock API

```bash
mkdir -p .tmp
docker compose -p dbt_decisions_it -f pytests/postgres/docker-compose.yml up -d --wait --build

```

Tear down when finished:
```bash
docker compose -p dbt_decisions_it -f pytests/postgres/docker-compose.yml down -v
docker rmi dbt_decisions_it-postgres   # `down -v` does not remove the built image
```

## Live API

Set `TYPESAFE_API_KEY` environment variable.

Start the harness with the live override (it puts the key into the container environment, visible via `docker inspect`):

```bash
mkdir -p .tmp
docker compose -p dbt_decisions_it -f pytests/postgres/docker-compose.yml -f pytests/postgres/docker-compose.live.yml up -d --wait --build
```

Tear down when finished:
```bash
docker compose -p dbt_decisions_it -f pytests/postgres/docker-compose.yml -f pytests/postgres/docker-compose.live.yml down -v
docker rmi dbt_decisions_it-postgres   # `down -v` does not remove the built image
```
