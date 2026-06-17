# Work Insights Cloud

Portable cloud ingest for Screenpipe work-insights.

## Local Development

```bash
cd cloud
docker compose up -d
export WORK_INSIGHTS_DATABASE_URL=postgres://work_insights:work_insights@localhost:55432/work_insights
export SUPABASE_URL=https://<project-ref>.supabase.co
export SUPABASE_ANON_KEY=<supabase-anon-key>
export WORK_INSIGHTS_AI_BASE_URL=http://localhost:11434/v1
export WORK_INSIGHTS_AI_SEGMENT_MODEL=qwen2.5:7b-instruct
export WORK_INSIGHTS_AI_DAILY_MODEL=qwen2.5:14b-instruct
export WORK_INSIGHTS_PUBLIC_BASE_URL=http://localhost:8089
export WORK_INSIGHTS_BIND_ADDR=0.0.0.0:8089
export RUST_LOG=info
cargo run -p work-insights-ingest-api
```

Full set of environment variables is documented in [`.env.example`](.env.example).


Bootstrap the first organization + owner before testing `/auth/session/exchange`
or `/me`:

```bash
cd cloud
export WORK_INSIGHTS_DATABASE_URL=postgres://work_insights:work_insights@localhost:55432/work_insights
cargo run -p work-insights-ingest-api --bin bootstrap_org -- \
  --org-name "Acme" \
  --org-slug acme \
  --owner-supabase-user-id <supabase-user-uuid> \
  --owner-email founder@acme.com \
  --domain acme.com
```

## Workspace Layout

Deployable processes live under `services/`. Library crates live under
`crates/`.

- `services/ingest-api`
  - public HTTP ingest and report-read API
- `services/report-runner`
  - one-shot daily report generator
- `crates/work-insights-db`
  - migrations, SQL queries, and DB transactions
- `crates/work-insights-ingest`
  - batch decode, validation, and DB ingest workflow
- `crates/work-insights-report`
  - report generation pipeline, prompts, and report read helpers
- `crates/ai-gateway`
  - OpenAI-compatible AI client

## Deployment Shape

The workspace currently exposes two deployable services:

- `work-insights-api`
  - long-running ingest and report-read API
- `work-insights-report-runner`
  - one-shot daily report generator for a single `org_id` / `user_id` / date

## Synchronous Ingest Flow

The ingest API processes and writes data on the request path:

```text
local sync -> work-insights-api -> Postgres
```

`PUT /v1/ingest/uploads/:batch_id` verifies the upload checksum and byte count,
decodes the JSONL body, inserts `content_atoms`, `input_signals`, and
`ingest_cursors` in a DB transaction, then returns `{ "status": "completed" }`.

## Stage 3 Daily Reports

User-level daily report reads are available through the API:

- `GET /v1/reports/me/daily?date=YYYY-MM-DD`
- `GET /v1/reports/me/timeline?date=YYYY-MM-DD`
- `GET /v1/reports/me/evidence/:atom_id`

The report pipeline uses an OpenAI-compatible AI gateway contract. Local
development is expected to point at Ollama or another local compatible server.
Production can point at Azure AI Foundry or another provider behind the same
HTTP shape.

Required env vars for the report runner: `WORK_INSIGHTS_DATABASE_URL`,
`WORK_INSIGHTS_AI_BASE_URL`. Optionally set `WORK_INSIGHTS_AI_API_KEY` for
authenticated providers. See [`.env.example`](.env.example) for the full list.

Generate a report manually with the runner:

```bash
cargo run -p work-insights-report-runner -- \
  generate-daily \
  --date 2026-06-10 \
  --org-id org_dev \
  --user-id user_dev
```

## EOD Scheduling

Stage 3 does not run an internal scheduler. The intended EOD path is:

1. local Screenpipe sync uploads the final batch for the day
2. an external scheduler or job runner executes `work-insights-report-runner generate-daily`
3. org-level reducers will later consume stored `user_reports`

This keeps the long-running ingest container separate from the short-lived
report generation workload while reusing the same report pipeline code.

## Identity and Onboarding

The API now splits authenticated user access from background ingest:

- `POST /auth/session/exchange`
- `GET /me`
- `POST /devices/register`
- `GET /devices`
- `POST /devices/:device_id/revoke`

The user-facing endpoints above expect `Authorization: Bearer <supabase-jwt>`,
mirror the user into `app_users`, resolve org membership, and manage per-device
credentials for ingest.

Background ingest endpoints now use `Authorization: Bearer <device-token>` as
the primary path. The server resolves canonical `org_id`, `app_users.id`, and
`devices.id` from that token before writing ingest rows.

Authenticated report reads under `/v1/reports/me/*` now use the Supabase JWT
path again and return correct data for newly ingested rows stamped with
canonical app and device ids.
