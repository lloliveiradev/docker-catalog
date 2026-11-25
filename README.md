<div align="center">

# Docker Catalog

Self-contained Compose stacks for local databases, queues, identity, observability, and AWS emulation.

[Usage](#usage) • [Catalog](#catalog) • [Conventions](#conventions) • [Troubleshooting](#troubleshooting)

</div>

Each directory is one stack. Copy the env file if you want different credentials or ports, then start only that directory. Stacks are meant to be disposable: `down -v` drops their data.

> [!NOTE]
> Defaults are development credentials, and most services bind host ports. Keep this catalog on a private machine.

## Prerequisites

- Docker Engine 24 or newer, with the Compose plugin (`docker compose version`)

## Usage

```bash
cd postgresql
cp .env.example .env   # optional
docker compose up -d
docker compose ps
docker compose down    # add -v to delete volumes
```

Optional services sit behind a profile:

```bash
cd postgresql
docker compose --profile admin up -d
```

Run one stack at a time. Several of them publish the same host ports (`5432`, `8080`, `9000`, `16686`).

Check every file the way CI does:

```bash
bash scripts/validate.sh
```

## Catalog

| Directory | Services | Open | Notes |
| --- | --- | --- | --- |
| [`aws-emulator`](aws-emulator) | AWS Emulator | `https://127.0.0.1:9297` | AWS APIs, S3 included. Builds a local image. State is lost on restart. See [AWS Emulator](#aws-emulator) |
| [`chartmuseum`](chartmuseum) | ChartMuseum | [localhost:8080](http://localhost:8080) | Local Helm chart storage |
| [`clickhouse`](clickhouse) | ClickHouse | [localhost:8123](http://localhost:8123) | Native protocol on `9000`. `--profile cloki` adds a log sink on `3101` |
| [`grafana`](grafana) | Grafana | [localhost:3000](http://localhost:3000) | `admin` / `admin` |
| [`infisical`](infisical) | Infisical, Postgres, Redis | [localhost:8080](http://localhost:8080) | Replace the example encryption keys in `.env` |
| [`jaeger`](jaeger) | Jaeger all-in-one | [localhost:16686](http://localhost:16686) | OTLP on `4317` and `4318` |
| [`jaeger/cassandra`](jaeger/cassandra) | Jaeger 1.53, Cassandra, HotROD | [localhost:16686](http://localhost:16686) | Pinned legacy collector. HotROD on `8080` |
| [`kafka`](kafka) | Kafka KRaft, Karapace | `localhost:9092` | Schema registry on [localhost:8081](http://localhost:8081). Host clients must use `localhost`, not the container DNS name |
| [`keycloak`](keycloak) | Keycloak, Postgres | [localhost:8080](http://localhost:8080) | `admin` / `admin`. Dev mode |
| [`mariadb`](mariadb) | MariaDB | `localhost:3306` | `app` / `app`. `--profile admin` adds phpMyAdmin on `8081` |
| [`mautic`](mautic) | Mautic, MariaDB | [localhost:8080](http://localhost:8080) | Database user `mautic` / `mautic` |
| [`minio`](minio) | MinIO | [localhost:9001](http://localhost:9001) | API on `9000`. `minio` / `minio123` |
| [`mongodb`](mongodb) | MongoDB | `localhost:27017` | `mongo` / `mongo`, database `app` |
| [`moodle`](moodle) | Moodle, MariaDB | [localhost:8080](http://localhost:8080) | Images from `bitnamilegacy`. HTTPS on `8443` |
| [`n8n`](n8n) | n8n | [localhost:5678](http://localhost:5678) | `--profile mcp` mounts `./kube` into a Kubernetes MCP server |
| [`nats`](nats) | NATS JetStream | `localhost:4222` | Monitoring on [localhost:8222](http://localhost:8222) |
| [`observability`](observability) | Prometheus, Grafana, Loki, Promtail, cAdvisor, node-exporter, Jaeger | [Grafana :3000](http://localhost:3000) | Also Prometheus `9090`, Loki `3100`, Jaeger `16686`, cAdvisor `8081` |
| [`otel`](otel) | OpenTelemetry Collector, Jaeger | [localhost:16686](http://localhost:16686) | Send OTLP to `4318` (HTTP) or `4317` (gRPC) |
| [`portainer`](portainer) | Portainer CE | [localhost:9443](https://localhost:9443) | HTTP fallback on `9000`. Mounts the Docker socket |
| [`postgresql`](postgresql) | Postgres 19 | `localhost:5432` | `app` / `app`. `uuidv7()` is built in. `--profile admin` adds pgAdmin on `5050` |
| [`postgresql/pgvector`](postgresql/pgvector) | Postgres 19, pgvector | `localhost:5432` | Same login, `uuidv7()`, and `admin` profile. Creates `vector` in `POSTGRES_DB` |
| [`postgresql/postgis`](postgresql/postgis) | Postgres 19, PostGIS 3 | `localhost:5432` | Same login, `uuidv7()`, and `admin` profile. Creates `postgis` in `POSTGRES_DB`. Builds a local image |
| [`rabbitmq`](rabbitmq) | RabbitMQ, management, STOMP | [localhost:15672](http://localhost:15672) | `rabbit` / `rabbit`. AMQP `5672`, STOMP `61613` |
| [`redis`](redis) | Redis 7 | `localhost:6379` | No password unless `REDIS_PASSWORD` is set. AOF enabled. `--profile admin` adds Redis Insight on [localhost:5540](http://localhost:5540) |
| [`sonarqube`](sonarqube) | SonarQube, Postgres | [localhost:9000](http://localhost:9000) | First login `admin` / `admin`, then SonarQube asks for a new password |
| [`sqlserver`](sqlserver) | SQL Server 2022 Developer | `localhost:1433` | `sa` / `SqlServer@123` |
| [`temporal`](temporal) | Temporal, UI, Postgres | [localhost:8080](http://localhost:8080) | Frontend on `7233`. Database `temporal` / `temporal` |
| [`wordpress`](wordpress) | WordPress, MariaDB | [localhost:8080](http://localhost:8080) | Database user `wordpress` / `wordpress` |

## AWS Emulator

[AWS Emulator](https://github.com/aws/aws-emulator) serves the AWS APIs on your machine, as account `000000000000`, with no AWS account or charges. The first start builds an image from the signed Linux package, a download of about 200 MB. Instructions here are for macOS and Linux.

```bash
cd aws-emulator
mkdir -p ~/.aws/emulator          # first, so Linux does not create it as root
docker compose up -d --wait
( . ./env.sh && aws s3 mb s3://demo && aws s3 ls )
```

`env.sh` (bash or zsh) points the AWS CLI and SDKs at the emulator and removes real credentials and endpoint overrides from that shell. Start your application the same way, for example `( . /path/to/aws-emulator/env.sh && npm run dev )`. Without it, your code talks to real AWS. Code that sets its own endpoint or credentials overrides these variables. SDKs that do not read `AWS_ENDPOINT_URL`, such as Java 1.x, Go v1, JavaScript v2, and old releases of the current ones, cannot use the emulator this way: they call real AWS, which rejects the emulator keys.

| Client | Certificate |
| --- | --- |
| AWS CLI, Python (boto3), Node.js | Set by `env.sh` |
| Rust, .NET | Add `SSL_CERT_FILE="$AWS_CA_BUNDLE"` to the command |
| Go, Java | See [Pointing your AWS SDK at AWS Emulator](https://docs.aws.amazon.com/emulator/latest/userguide/point-sdk-to-emulator.html) |

Telemetry is off in this stack; the product's own default is on. Linux users with a uid other than `1000` set `EMULATOR_USER` in `.env`.

Limits, as seen on release 1.0.611:

- State lives in memory. A restart drops buckets, queues, and tables and issues new keys. Recreate them with a script, then restart your application.
- The RDS endpoint is not a real PostgreSQL: `generate_series`, `CREATE TYPE`, PL/pgSQL functions, and pgvector operators fail. Use the `postgresql` stacks for database work.
- Lambda runs on built-in runtimes. The Python one has no `ctypes`, so expect native libraries not to load.
- IAM permissions are not enforced. Do not test policies against it.
- Applications in other containers cannot connect: ports are published on loopback and the certificate covers only `localhost` and `127.0.0.1`.
- A browser uploading through a presigned URL has to trust `~/.aws/emulator/9297/ca.pem`, which changes on every start.

## Conventions

- Every stack is a `compose.yaml` plus a `.env.example`. Compose loads `.env` from that directory when you create one.
- Variable defaults live in the compose file, so `docker compose up` works without copying the example.
- Images are pinned when a floating tag would drop flags or break clients. A few upstream projects only publish `latest` (`cloki`, Infisical, the Kubernetes MCP image). `aws-emulator` installs the latest release on purpose, since fixes ship only there.
- Optional UIs and extras use profiles (`admin`, `cloki`, `mcp`) so the default command stays small.
- Data is stored in named volumes. `docker compose down -v` removes them. `aws-emulator` is the exception and keeps everything in memory.
- A stack with no suitable published image carries a `Dockerfile`: `postgresql/postgis`, because the official PostGIS image for Postgres 19 is amd64 only, and `aws-emulator`, because AWS publishes no image. Compose builds it on the first `up`; after editing it, run `docker compose up -d --build`. `docker compose pull` skips it, so pick up new releases with `docker compose build --pull --no-cache`, then `docker compose up -d`.
- SQL files in `initdb/` run only on the first start of an empty volume, against the default database. In any other database, run `CREATE EXTENSION` yourself.
- The three Postgres variants keep separate volumes. All of them preload `pg_stat_statements`; run `CREATE EXTENSION pg_stat_statements;` to query it.

## Troubleshooting

**Port already allocated.** Another stack, or a local install, owns that port. Stop it, or change the host port in `.env`.

**AWS Emulator calls fail with `AccessDenied` or a certificate error.** The emulator restarted and wrote new keys and a new certificate: restart your application so it reads them. A shell that was not set up with `env.sh` is using other credentials.

**AWS Emulator exits with code 137.** It reached its memory limit and lost its state. Raise `EMULATOR_MEMORY` in `.env`.

**AWS Emulator answers `NotImplemented` (HTTP 501).** That operation is not emulated in the installed release. Rebuild with `docker compose build --pull --no-cache`, then run `docker compose up -d`.

**Postgres keeps restarting after the upgrade from 16.** The volume holds data from the older version. Postgres 19 refuses to start on it and leaves the old files intact; `docker compose logs postgres` shows `mkdir: cannot create directory '/var/lib/postgresql': Permission denied`.

To discard that data, run `docker compose down -v`, then `docker compose up -d`. To keep it, run this from `postgresql/`, one line at a time, and stop if a command fails:

```bash
docker compose down                       # no -v here
git show 22d7cc4:postgresql/compose.yaml > /tmp/pg16.yaml
docker compose --project-directory . -f /tmp/pg16.yaml up -d --wait postgres
docker compose --project-directory . -f /tmp/pg16.yaml exec -T postgres sh -c 'pg_dumpall -U "$POSTGRES_USER"' > ~/pg16-dump.sql
grep "database cluster dump complete" ~/pg16-dump.sql   # no output means the dump failed: stop
docker compose --project-directory . -f /tmp/pg16.yaml down
docker volume rm postgresql_postgres-data # deletes the 16 data
docker compose up -d --wait postgres
docker compose exec -T postgres sh -c 'psql -U "$POSTGRES_USER" -d postgres' < ~/pg16-dump.sql
```

During the import, errors saying that your user's role and database already exist are expected.

**Redis Insight opens without a database.** It registers the Redis connection only after its terms are accepted. To accept them from the stack, set `REDIS_UI_ACCEPT_TERMS=true` in `redis/.env` and run `docker compose --profile admin up -d`. Otherwise accept them on screen and add the database with host `redis`, port `6379`, and your password if you set one.

**`redis-cli` answers `NOAUTH`.** `REDIS_PASSWORD` is set. Run `docker compose exec redis redis-cli --askpass`.

**Kafka client from the host gets the wrong broker address.** Connect to `localhost:9092`. Containers on the Compose network connect to `kafka:9092`.

**SonarQube exits during bootstrap.** The stack sets `SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true`. If Elasticsearch still refuses to start, raise `vm.max_map_count` to at least `262144` on the Docker host.

**SQL Server restarts in a loop.** `MSSQL_SA_PASSWORD` must be at least 8 characters and include upper case, lower case, a digit, and a symbol.

**Keycloak takes a minute on the first start.** `start-dev` runs the schema migration before the UI answers on port `8080`.

**Moodle or MariaDB from Bitnami fails to pull.** Free Bitnami application images moved to `bitnamilegacy`. This stack already uses that namespace.

**Observability has empty logs or cAdvisor errors.** Promtail and cAdvisor read the Docker host's container logs and cgroup filesystem. That path is reliable on Linux. Docker Desktop on macOS does not expose `/var/lib/docker/containers` the same way.

**Infisical will not start.** `ENCRYPTION_KEY` must stay a 32-character hex string. The value in `.env.example` is the public self-host example. Change it before storing real secrets.

> [!WARNING]
> `scripts/prune-docker.sh` deletes every container, image, network, and volume on the local Docker daemon, including projects that are not part of this catalog. It asks you to type `prune` before it does anything.
