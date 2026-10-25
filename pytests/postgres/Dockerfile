# postgres + PL/Python + the jev extension (pgjev), pinned to an exact commit.
# Derived from pgjev's own Dockerfile (PostgreSQL License, see NOTICE): pgjev is pure PL/Python, so
# "installing" it is copying jev.control and sql/jev--*.sql into the extension directory.
# Build args: PG_MAJOR (pgjev supports 14-17), PGJEV_REF (commit, from PINNED_PGJEV).
ARG PG_MAJOR=16
FROM postgres:${PG_MAJOR}
ARG PG_MAJOR
ARG PGJEV_REF
RUN test -n "${PGJEV_REF}" \
 && apt-get update \
 && apt-get install -y --no-install-recommends postgresql-plpython3-${PG_MAJOR} ca-certificates git \
 && git clone https://github.com/realZachi/pg-jev /tmp/pgjev \
 && git -C /tmp/pgjev checkout "${PGJEV_REF}" \
 && cp /tmp/pgjev/jev.control /tmp/pgjev/sql/jev--*.sql /usr/share/postgresql/${PG_MAJOR}/extension/ \
 && apt-get purge -y git && apt-get autoremove -y \
 && rm -rf /var/lib/apt/lists/* /tmp/pgjev
