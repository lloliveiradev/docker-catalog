# PostgreSQL Variants Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Three independent PostgreSQL 19 stacks in the catalog: base, pgvector and PostGIS.

**Architecture:** One directory per variant under `postgresql/`, each with its own `compose.yaml`, `.env.example`, Compose project name and data volume. Only PostGIS builds a local image.

**Tech Stack:** Docker Compose, PostgreSQL 19, pgvector, PostGIS 3, pgAdmin 9.

**Spec:** `docs/superpowers/specs/2026-11-25-postgresql-variants-design.md`

## Global Constraints

- Images: `postgres:19-trixie`, `pgvector/pgvector:pg19-trixie`, `dpage/pgadmin4:9`. PostGIS builds `FROM postgres:19-trixie`.
- Service name `postgres`; volume `postgres-data:/var/lib/postgresql`.
- `command`: `postgres -c shared_preload_libraries=pg_stat_statements` in all three.
- Healthcheck: `pg_isready -h 127.0.0.1 -U <user> -d <db>`, so the temporary init server (socket only) never counts as healthy.
- Variable names, defaults, `admin` profile and `.env.example` keys stay as in today's `postgresql/`.
- No commits: the user has not asked for any. Leave the uncommitted `redis/` changes untouched.
- Tests use project names `dctest-*` and ports `55432` / `55050`. Port 5432 belongs to a running container of the user; do not stop it.

## Review Focus

1. Data written before `down` must still be there after `up` (a wrong mount path loses it silently). Task 1.
2. A leftover PG 16 volume must make PG 19 refuse to start and stay intact. Task 4.
3. A client connecting right after the first `up --wait` must find the extension already created. Tasks 2, 3.
4. Custom `POSTGRES_USER` / `POSTGRES_DB`: healthy, and the extension lands in that database. Tasks 1-3.
5. pgAdmin 9 must boot with the default `admin@example.com`. Tasks 1-3.

---

### Task 1: Base stack on PostgreSQL 19

**Files:**
- Modify: `postgresql/compose.yaml`
- Test: `<scratchpad>/smoke.sh` (not part of the repo)

**Interfaces:**
- Produces: `smoke.sh <stack-dir> <base|vector|postgis>`, exit 0 when every assertion holds. Tasks 2 and 3 reuse it.

- [ ] **Step 1: Write `smoke.sh`.** Env `POSTGRES_USER=smoke`, `POSTGRES_PASSWORD=smoke`, `POSTGRES_DB=smokedb`, project `dctest-<variant>`, `down -v` on exit. After `up -d --build --wait postgres`, query over TCP and assert:
  - `current_setting('server_version_num')::int / 10000` → `19`
  - `uuid_extract_version(uuidv7())` → `7`
  - `current_setting('shared_preload_libraries')` → `pg_stat_statements`
  - `CREATE EXTENSION pg_stat_statements`, then `count(*) > 0 FROM pg_stat_statements` → `t`
  - vector: `'[1,2,3]'::vector <-> '[1,2,4]'::vector` → `1`
  - postgis: `ST_Distance('POINT(0 0)'::geometry, 'POINT(3 4)'::geometry)` → `5`
  - insert into `keep(id uuid DEFAULT uuidv7())`, `down`, `up --wait`, `count(*)` → `1`
  - `--profile admin up -d`, then `http://127.0.0.1:55050/misc/ping` answers
- [ ] **Step 2: Run `smoke.sh postgresql base`.** Expected: FAIL on the version assertion (`16`).
- [ ] **Step 3: Update `postgresql/compose.yaml`** per Global Constraints.
- [ ] **Step 4: Run `smoke.sh postgresql base`.** Expected: PASS.

### Task 2: pgvector stack

**Files:**
- Create: `postgresql/pgvector/compose.yaml`, `postgresql/pgvector/.env.example`, `postgresql/pgvector/initdb/01-extensions.sql`

**Interfaces:**
- Consumes: `smoke.sh`. Project name `postgresql-pgvector`. Init scripts mount at `/docker-entrypoint-initdb.d:ro`.

- [ ] **Step 1: Run `smoke.sh postgresql/pgvector vector`.** Expected: FAIL, no compose file.
- [ ] **Step 2: Create the three files.** The SQL is `CREATE EXTENSION IF NOT EXISTS vector;`.
- [ ] **Step 3: Run `smoke.sh postgresql/pgvector vector`.** Expected: PASS.

### Task 3: PostGIS stack

**Files:**
- Create: `postgresql/postgis/Dockerfile`, `postgresql/postgis/compose.yaml`, `postgresql/postgis/.env.example`, `postgresql/postgis/initdb/01-extensions.sql`

**Interfaces:**
- Consumes: `smoke.sh`. Project name `postgresql-postgis`, image `docker-catalog/postgis:19`, `build: .`.

- [ ] **Step 1: Run `smoke.sh postgresql/postgis postgis`.** Expected: FAIL, no compose file.
- [ ] **Step 2: Create the files.** Dockerfile installs `postgresql-19-postgis-3` and `postgresql-19-postgis-3-scripts` with `--no-install-recommends` and removes the apt lists. The SQL is `CREATE EXTENSION IF NOT EXISTS postgis;`.
- [ ] **Step 3: Run `smoke.sh postgresql/postgis postgis`.** Expected: PASS, image architecture `arm64`.

### Task 4: Cleanup, docs, whole-catalog check

**Files:**
- Delete: `postgresql/postgres/` (untracked; copy to scratchpad first)
- Modify: `README.md`

- [ ] **Step 1: Back up and delete `postgresql/postgres/`.**
- [ ] **Step 2: Update `README.md`:** catalog rows for the three variants (PostgreSQL 19, `uuidv7()` built in, extensions created only in `POSTGRES_DB` on first init, PostGIS needs `--build` after Dockerfile changes), a convention line for local builds, a troubleshooting entry for old-version volumes.
- [ ] **Step 3: Old-volume check.** Initialise `dctest-old_postgres-data` with `postgres:16-alpine`, start the base stack on it as project `dctest-old`. Expected: startup fails with the image's old-data error; `PG_VERSION` in the volume still reads `16`. Remove the test volume.
- [ ] **Step 4: Run `bash scripts/validate.sh`.** Expected: exit 0, three `postgresql*` stacks listed.
- [ ] **Step 5: Confirm no `dctest-*` containers or volumes remain.**

## Usage report

| Role | Task | Model | Tokens | Tool uses | Duration | Fix rounds |
| --- | --- | --- | --- | --- | --- | --- |
| Implementation (inline) | 1 Base on PG 19 | Sonnet 5.5 (session) | not measured | - | - | 0 |
| Implementation (inline) | 2 pgvector | Sonnet 5.5 (session) | not measured | - | - | 0 |
| Implementation (inline) | 3 PostGIS | Sonnet 5.5 (session) | not measured | - | - | 0 |
| Implementation (inline) | 4 Cleanup, README, checks | Sonnet 5.5 (session) | not measured | - | - | 0 |
| Review | Whole change | opus | 123,100 | 35 | 10m22s | 1 |
| **Total (dispatched)** | | | **123,100** | **35** | **10m22s** | **1** |

- Fix round (README recovery steps): root cause was the implementer's wording, never executed before review.
- Task 4 in-task correction: plan defect, the expected startup error was assumed, not observed.
