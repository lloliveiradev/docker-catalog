# AWS Emulator catalog stack

Approved on 2026-11-25. Small change.

## Intent

Run the official AWS Emulator locally from the catalog, on macOS or Linux, to develop against AWS APIs. S3 matters most.

## Goals

- `cd aws-emulator && docker compose up -d` serves `https://127.0.0.1:9297`.
- `. ./env.sh` points the AWS CLI and SDKs of that shell at the emulator, and no call from it can reach real AWS.

## Non-goals

- Replacing the `postgresql/` stacks, testing IAM permissions, or keeping state across restarts.
- Making the emulator reachable from other Compose projects.

## Anti-goals

- A port open beyond loopback.
- A command from the configured shell that can hit a real AWS account.

## Constraints

- AWS publishes no image: build one from the Linux package, always `LTS/latest`.
- Catalog conventions: `compose.yaml` plus `.env.example`, defaults in the compose file, `scripts/validate.sh` passes.
- The same port inside and outside the container: the emulator writes it into its files and URLs.

## Approaches

1. **Image built from the signed Linux package.** The documented path on macOS. **Picked.**
2. **Native process.** Linux only.
3. **Embedded mode.** Rust tests only.

## Decided how

- `Dockerfile` verifies the package signature against key `98BCF336A3BE53B734E967C52E5BF49BD940F624`.
- Ports on `127.0.0.1` only: API `9297`, resource endpoints `9298-9317`.
- Emulator files in `~/.aws/emulator/`, at the same path inside and outside the container.
- Telemetry off by default. Memory limit 2 GiB, read-only root filesystem, no capabilities.
- `env.sh` exports the connection variables and removes real credentials and endpoint overrides.
- README row, usage and limits.

## Left to the builder

Variable names, healthcheck, README wording.
