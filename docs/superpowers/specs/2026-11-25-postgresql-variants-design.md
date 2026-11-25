# PostgreSQL variants: base, pgvector, PostGIS

Approved on 2026-11-25. Small change.

## Intent

Make it easy to pick a plain Postgres, a pgvector one, or a PostGIS one from the catalog, with UUIDv7 available.

## Goals

- `postgresql/`, `postgresql/pgvector/` and `postgresql/postgis/` each start on their own with `docker compose up -d`.
- All three run PostgreSQL 19, where `uuidv7()` is built in.
- All three run natively on arm64 and amd64.

## Non-goals

- A "with or without UUIDv7" switch. Every variant has `uuidv7()`.
- A `uuid_generate_v7()` alias.
- The Postgres bundled inside other stacks (Infisical, Keycloak, SonarQube, Temporal).
- A combined pgvector + PostGIS variant.
- Migrating data from PostgreSQL 16. There are no local volumes.

## Anti-goals

- A variant that only runs under emulation on Apple Silicon.
- Two variants sharing one data volume.

## Constraints

- PostgreSQL 18+ images keep data under `/var/lib/postgresql/<major>/docker`; the volume mounts at `/var/lib/postgresql`.
- `postgis/postgis:19-3.7` is published for amd64 only (checked 2026-11-25).
- Catalog conventions: one directory per stack, `compose.yaml` plus `.env.example`, defaults in the compose file, optional UIs behind a profile. `scripts/validate.sh` parses every `compose.yaml`.

## Approaches

1. **One directory per variant** (like `jaeger/cassandra`). The choice is visible in the tree and each variant has its own volume. The pgAdmin service repeats three times. **Picked.**
2. **Compose profiles.** The unprofiled base service would start too and fight for port 5432.
3. **Image chosen through `.env`.** Hides the choice, shares one volume between variants, and PostGIS needs a build anyway.

## Decided how

| Variant | Image |
| --- | --- |
| `postgresql/` | `postgres:19-trixie` |
| `postgresql/pgvector/` | `pgvector/pgvector:pg19-trixie`, creates `vector` on first init |
| `postgresql/postgis/` | local build: `postgres:19-trixie` + `postgresql-19-postgis-3`, creates `postgis` on first init |

- Debian trixie in all three (the base leaves Alpine).
- `pg_stat_statements` preloaded through a command flag in all three.
- pgAdmin moves from 8 to 9, behind the `admin` profile, in all three.
- Delete the untracked `postgresql/postgres/` directory.
- README catalog and notes updated.

## Left to the builder

File layout of the init scripts and the Dockerfile, Compose project names, README wording.
