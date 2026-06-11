# Work Insights Cloud

Portable cloud ingest for Screenpipe work-insights.

## Local Development

```bash
cd cloud
docker compose up -d
export WORK_INSIGHTS_DATABASE_URL=postgres://work_insights:work_insights@localhost:55432/work_insights
export SUPABASE_URL=https://<project-ref>.supabase.co
export SUPABASE_ANON_KEY=<supabase-anon-key>
export WORK_INSIGHTS_BLOB_BACKEND=local
export WORK_INSIGHTS_BLOB_DIR=$HOME/.screenpipe/work-insights-cloud/blobs
export WORK_INSIGHTS_QUEUE_BACKEND=local
export WORK_INSIGHTS_QUEUE_DIR=$HOME/.screenpipe/work-insights-cloud/queue
export WORK_INSIGHTS_AI_BASE_URL=http://localhost:11434/v1
export WORK_INSIGHTS_AI_SEGMENT_MODEL=qwen2.5:7b-instruct
export WORK_INSIGHTS_AI_DAILY_MODEL=qwen2.5:14b-instruct
cargo run -p work-insights-ingest-api
```

The blob directory defaults to `~/.screenpipe/work-insights-cloud/blobs` and
the local queue directory defaults to `~/.screenpipe/work-insights-cloud/queue`.
Both should stay outside the repository.

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

Run the DB worker in another shell:

```bash
cd cloud
export WORK_INSIGHTS_DATABASE_URL=postgres://work_insights:work_insights@localhost:55432/work_insights
export WORK_INSIGHTS_BLOB_BACKEND=local
export WORK_INSIGHTS_BLOB_DIR=$HOME/.screenpipe/work-insights-cloud/blobs
export WORK_INSIGHTS_QUEUE_BACKEND=local
export WORK_INSIGHTS_QUEUE_DIR=$HOME/.screenpipe/work-insights-cloud/queue
cargo run -p work-insights-db-worker
```

## Workspace Layout

Deployable processes live under `services/`. Library crates live under
`crates/`.

- `services/ingest-api`
  - public HTTP ingest and report-read API
- `services/db-worker`
  - private background process that drains queued ingest jobs into Postgres
- `services/report-runner`
  - one-shot daily report generator
- `crates/work-insights-blob`
  - blob storage trait and filesystem adapter
- `crates/work-insights-db`
  - migrations, SQL queries, and DB transactions
- `crates/work-insights-ingest`
  - batch decode, validation, and DB ingest workflow
- `crates/work-insights-queue`
  - queue trait, ingest job DTO, and local durable queue adapter
- `crates/work-insights-report`
  - report generation pipeline, prompts, and report read helpers
- `crates/ai-gateway`
  - OpenAI-compatible AI client

When adding a new deployable process, add it under `services/<name>`. Put
substantial non-entrypoint behavior under `crates/<name>` only when it is
domain logic, infrastructure integration, or testable workflow code rather than
process wiring.

Infrastructure adapters are selected by env, not by changing service code:

- `WORK_INSIGHTS_BLOB_BACKEND=local|azure`
- `WORK_INSIGHTS_QUEUE_BACKEND=local|azure_service_bus`

Service startup should call the crate factories:

- `work_insights_blob::blob_store_from_env()`
- `work_insights_queue::queue_from_env()`

## Deployment Shape

The workspace currently exposes three deployable services:

- `work-insights-api`
  - long-running ingest and report-read API
- `work-insights-db-worker`
  - long-running private worker that reads blob-pointer jobs and writes batches to Postgres
- `work-insights-report-runner`
  - one-shot daily report generator for a single `org_id` / `user_id` / date

## Async Ingest Flow

The ingest API accepts uploads quickly and does not insert atoms/signals into
Postgres on the request path.

```text
local sync -> work-insights-api -> blob store -> queue -> work-insights-db-worker -> Postgres
```

`PUT /v1/ingest/uploads/:batch_id` verifies the upload checksum and byte count,
writes the JSONL blob, publishes an `IngestBatchJob`, marks the batch queued,
and returns `{ "status": "queued" }`.

`work-insights-db-worker` loads the blob, validates record counts, writes
`content_atoms`, `input_signals`, and `ingest_cursors` in a DB transaction, then
marks the batch `completed`. Bad payloads are dead-lettered; temporary failures
are retried by returning the local queue message to pending.

## Azure Queue Config

To use Azure Service Bus instead of the local queue:

```bash
export WORK_INSIGHTS_QUEUE_BACKEND=azure_service_bus
export WORK_INSIGHTS_SERVICE_BUS_CONNECTION_STRING='Endpoint=sb://<namespace>.servicebus.windows.net/;SharedAccessKeyName=<policy>;SharedAccessKey=<key>'
export WORK_INSIGHTS_SERVICE_BUS_QUEUE=ingest-batches
export WORK_INSIGHTS_SERVICE_BUS_DEAD_LETTER_QUEUE=ingest-batches-dead-letter
```

Both `work-insights-ingest-api` and `work-insights-db-worker` read the same queue
settings. The queue crate parses the Service Bus connection string, builds the
Azure adapter, and maps queue operations to:

- publish -> `send_message`
- receive -> `peek_lock_message2`
- ack -> `delete_message`
- retry -> `unlock_message`
- dead-letter -> send to configured dead-letter queue, then delete original

To use Azure Blob Storage instead of the local filesystem blob store:

```bash
export WORK_INSIGHTS_BLOB_BACKEND=azure
export WORK_INSIGHTS_STORAGE_CONNECTION_STRING='DefaultEndpointsProtocol=https;AccountName=<account>;AccountKey=<key>;EndpointSuffix=core.windows.net'
export WORK_INSIGHTS_BLOB_CONTAINER=work-insights-batches
```

The blob crate parses the storage connection string, builds an Azure
`BlobServiceClient`, and uses `<container>/<object_key>` for batch archive reads
and writes.

## Stage 3 Daily Reports

User-level daily report reads are available through the API:

- `GET /v1/reports/me/daily?date=YYYY-MM-DD`
- `GET /v1/reports/me/timeline?date=YYYY-MM-DD`
- `GET /v1/reports/me/evidence/:atom_id`

The report pipeline uses an OpenAI-compatible AI gateway contract. Local
development is expected to point at Ollama or another local compatible server.
Production can point at Azure AI Foundry or another provider behind the same
HTTP shape.

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
