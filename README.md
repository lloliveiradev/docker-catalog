<div align="center">

# Docker Catalog

Self-contained Compose stacks for local databases, queues, identity, and observability.

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
| [`postgresql`](postgresql) | Postgres 16 | `localhost:5432` | `app` / `app`. `--profile admin` adds pgAdmin on `5050` |
| [`rabbitmq`](rabbitmq) | RabbitMQ, management, STOMP | [localhost:15672](http://localhost:15672) | `rabbit` / `rabbit`. AMQP `5672`, STOMP `61613` |
| [`redis`](redis) | Redis 7 | `localhost:6379` | No authentication. AOF enabled |
| [`sonarqube`](sonarqube) | SonarQube, Postgres | [localhost:9000](http://localhost:9000) | First login `admin` / `admin`, then SonarQube asks for a new password |
| [`sqlserver`](sqlserver) | SQL Server 2022 Developer | `localhost:1433` | `sa` / `SqlServer@123` |
| [`temporal`](temporal) | Temporal, UI, Postgres | [localhost:8080](http://localhost:8080) | Frontend on `7233`. Database `temporal` / `temporal` |
| [`wordpress`](wordpress) | WordPress, MariaDB | [localhost:8080](http://localhost:8080) | Database user `wordpress` / `wordpress` |

## Conventions

- Every stack is a `compose.yaml` plus a `.env.example`. Compose loads `.env` from that directory when you create one.
- Variable defaults live in the compose file, so `docker compose up` works without copying the example.
- Images are pinned when a floating tag would drop flags or break clients. A few upstream projects only publish `latest` (`cloki`, Infisical, the Kubernetes MCP image).
- Optional UIs and extras use profiles (`admin`, `cloki`, `mcp`) so the default command stays small.
- Data is stored in named volumes. `docker compose down -v` removes them.

## Troubleshooting

**Port already allocated.** Another stack, or a local install, owns that port. Stop it, or change the host port in `.env`.

**Kafka client from the host gets the wrong broker address.** Connect to `localhost:9092`. Containers on the Compose network connect to `kafka:9092`.

**SonarQube exits during bootstrap.** The stack sets `SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true`. If Elasticsearch still refuses to start, raise `vm.max_map_count` to at least `262144` on the Docker host.

**SQL Server restarts in a loop.** `MSSQL_SA_PASSWORD` must be at least 8 characters and include upper case, lower case, a digit, and a symbol.

**Keycloak takes a minute on the first start.** `start-dev` runs the schema migration before the UI answers on port `8080`.

**Moodle or MariaDB from Bitnami fails to pull.** Free Bitnami application images moved to `bitnamilegacy`. This stack already uses that namespace.

**Observability has empty logs or cAdvisor errors.** Promtail and cAdvisor read the Docker host's container logs and cgroup filesystem. That path is reliable on Linux. Docker Desktop on macOS does not expose `/var/lib/docker/containers` the same way.

**Infisical will not start.** `ENCRYPTION_KEY` must stay a 32-character hex string. The value in `.env.example` is the public self-host example. Change it before storing real secrets.

> [!WARNING]
> `scripts/prune-docker.sh` deletes every container, image, network, and volume on the local Docker daemon, including projects that are not part of this catalog. It asks you to type `prune` before it does anything.
