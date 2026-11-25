# AWS Emulator Stack Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A catalog stack that runs the AWS Emulator locally and connects a shell to it safely.

**Architecture:** `aws-emulator/` builds an image from the signed Linux package and shares `~/.aws/emulator` with the host at the same path. `env.sh` configures the calling shell.

**Tech Stack:** Docker Compose, Amazon Linux 2023, AWS Emulator, bash/zsh.

**Spec:** `docs/superpowers/specs/2026-11-25-aws-emulator-design.md`

## Global Constraints

- Package URL base `https://downloads.aws.com/aws-emulator/packages/aws-emulator/LTS/latest`; signing key `98BCF336A3BE53B734E967C52E5BF49BD940F624`.
- Variables and defaults: `EMULATOR_PORT=9297`, `EMULATOR_ENDPOINT_PORTS=9298-9317`, `EMULATOR_TELEMETRY=off`, `EMULATOR_MEMORY=2g`, `EMULATOR_HOME=$HOME`, `EMULATOR_USER=1000`.
- Published ports bind `127.0.0.1`. No `image:` name next to `build:`.
- No commits: the user asked for a branch and the implementation.
- Tests live in the scratchpad, set `EMULATOR_HOME` inside it, use project `dctest-emulator`, and must not write to the real `~/.aws`. Do not touch the user's running containers.

## Review Focus

1. A shell holding real credentials, a profile, `AWS_ENDPOINT_URL_S3` or `AWS_IGNORE_CONFIGURED_ENDPOINT_URLS` must still reach only the emulator. Task 2.
2. `env.sh` with the emulator stopped must fail loudly and leave the shell pointed at loopback. Task 2.
3. Port or home changed in `.env` or in the shell: `env.sh` and Compose must agree. Task 2.
4. `env.sh` sourced from zsh and bash, from another directory, with a space in the home path, under `set -u`. Task 2.
5. Common SDKs must do S3 with path and certificate handling as configured, not only the CLI. Task 3.

---

### Task 1: The stack

**Files:**
- Create: `aws-emulator/Dockerfile`, `aws-emulator/compose.yaml`, `aws-emulator/.env.example`

**Interfaces:**
- Produces: service `aws-emulator`; files `config`, `emulator_credentials`, `ca.pem` in `$EMULATOR_HOME/.aws/emulator/$EMULATOR_PORT/`.

- [ ] **Step 1: Write `stack.sh`.** Assert: `up -d --build --wait` succeeds; published addresses are all `127.0.0.1` for 9297 and 9298-9317; the log says telemetry is disabled; root filesystem read-only; memory 2 GiB; the three files exist on the host; after `down` they are gone; a Dockerfile copy with a wrong fingerprint fails to build.
- [ ] **Step 2: Run it.** Expected: FAIL, no compose file.
- [ ] **Step 3: Create the three files.**
- [ ] **Step 4: Run it.** Expected: PASS.

### Task 2: `env.sh`

**Files:**
- Create: `aws-emulator/env.sh`

**Interfaces:**
- Consumes: the files and variables of Task 1.
- Produces: `. aws-emulator/env.sh` exports `AWS_ENDPOINT_URL`, `AWS_CONFIG_FILE`, `AWS_SHARED_CREDENTIALS_FILE`, `AWS_CA_BUNDLE`, `NODE_EXTRA_CA_CERTS`, region `us-east-1`; returns 1 when the credentials file is missing.

- [ ] **Step 1: Write `envsh.sh`** covering Review Focus 1-4, in both shells.
- [ ] **Step 2: Run it.** Expected: FAIL, no `env.sh`.
- [ ] **Step 3: Create `env.sh`.** Unset credential and endpoint-override variables first, before any check can fail.
- [ ] **Step 4: Run it.** Expected: PASS.

### Task 3: S3 through real clients

**Files:**
- Test only: `s3.sh` plus boto3 and AWS SDK for JavaScript clients installed in the scratchpad.

- [ ] **Step 1: Write and run `s3.sh`** against the stack through `env.sh`: multipart upload round trip, list with pagination, copy, delete, metadata and content type, ranged read, versioning, presigned PUT and GET, CORS preflight, boto3 and Node round trips without endpoint or certificate settings in code. Expected: each line reports `ok`, or the failure is recorded as a limit.

### Task 4: README and whole-catalog check

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add** the catalog row, a usage section, the Dockerfile convention and troubleshooting entries for what Tasks 1-3 showed.
- [ ] **Step 2: Run** `bash scripts/validate.sh`. Expected: exit 0, `aws-emulator/compose.yaml` listed; no `dctest-*` leftovers.

## Usage report

| Role | Task | Model | Tokens | Tool uses | Duration | Fix rounds |
| --- | --- | --- | --- | --- | --- | --- |
| Implementation (inline) | 1 Stack | Sonnet 5.5 (session) | not measured | - | - | 0 |
| Implementation (inline) | 2 env.sh | Sonnet 5.5 (session) | not measured | - | - | 0 |
| Implementation (inline) | 3 S3 clients | Sonnet 5.5 (session) | not measured | - | - | 0 |
| Implementation (inline) | 4 README | Sonnet 5.5 (session) | not measured | - | - | 0 |
| Review | Whole change | opus | 164,994 | 59 | 15m04s | 1 |
| **Total (dispatched)** | | | **164,994** | **59** | **15m04s** | **1** |

- Fix round (env.sh safety): root cause was a brief gap. Review Focus covered current credential variables only, with no case for executing the script, stale files or shell hooks.
