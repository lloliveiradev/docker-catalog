# postgis/postgis publishes PostgreSQL 19 for amd64 only, so build on the official image.
FROM postgres:19-trixie

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    "postgresql-$PG_MAJOR-postgis-3" \
    "postgresql-$PG_MAJOR-postgis-3-scripts" \
  && rm -rf /var/lib/apt/lists/*
