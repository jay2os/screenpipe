# THIS is AI GENERATED doc. Will review it later.

# Work Insights Local README

This document covers how to run and validate Work Insights locally across:

- Stage 1: local extraction and spool
- Stage 2: cloud ingest and storage
- Stage 3: daily user report generation

Current scope:

- User-level daily reports are implemented.
- Org-level reports are not implemented yet.
- Stage 3 runs through manual API calls. There is no internal end-of-day scheduler yet.

## What each stage does

### Stage 1

The Screenpipe daemon:

- reads local Screenpipe data through the local API
- fetches `/search` records for `ocr`, `audio`, and `input`
- cleans and deduplicates them into content atoms and input signals
- writes local batch files under the Screenpipe data directory

Artifacts written locally:

- `~/.screenpipe/work-insights/cursor.json`
- `~/.screenpipe/work-insights/batches/*.jsonl`
- `~/.screenpipe/work-insights/batches/*.manifest.json`

### Stage 2

The same daemon upload loop:

- finds pending Stage 1 spool files
- requests an upload ticket from the cloud API
- uploads the JSONL batch
- marks the batch as uploaded locally
- persists the batch, atoms, input signals, and cursors in Postgres

Additional local artifacts:

- `~/.screenpipe/work-insights/uploaded/*.uploaded.json`

### Stage 3

The cloud API:

- reads ingested atoms and input signals for a user/day
- performs deterministic timeline segmentation
- calls an OpenAI-compatible AI gateway for segment extraction and daily reduction
- stores the final daily report, timeline segments, segment reports, and agent runs

Manual report endpoints:

- `POST /v1/reports/me/daily/generate`
- `GET /v1/reports/me/daily?date=YYYY-MM-DD`
- `GET /v1/reports/me/timeline?date=YYYY-MM-DD`
- `GET /v1/reports/me/evidence/:atom_id`

## Prerequisites

You need:

- a built `screenpipe` binary
- Docker for local Postgres in `cloud/docker-compose.yml`
- Rust toolchain for `cargo run -p work-insights-api`
- optional Ollama for Stage 3 AI-backed reports

If you already built the daemon manually, that is enough for Stage 1 and Stage 2.

## 1. Build the daemon

From the repo root:

```bash
cargo build --release
```

The daemon binary used below is:

```bash
./target/release/screenpipe
```

## 2. Start local cloud infrastructure

From [cloud/docker-compose.yml](/home/jayshiai/Projects/2os/capture/screenpipe/cloud/docker-compose.yml):

```bash
cd cloud
docker compose up -d
```

This starts local Postgres on `127.0.0.1:55432`.

## 3. Start the Work Insights cloud API

From the repo root or from `cloud/`, export:

```bash
export WORK_INSIGHTS_DATABASE_URL=postgres://work_insights:work_insights@127.0.0.1:55432/work_insights
export WORK_INSIGHTS_INGEST_TOKEN=dev-token
export WORK_INSIGHTS_DEFAULT_ORG_ID=org_dev
export WORK_INSIGHTS_DEFAULT_USER_ID=user_dev
export WORK_INSIGHTS_DEFAULT_DEVICE_ID=dev_dev
export WORK_INSIGHTS_BLOB_DIR=$HOME/.screenpipe/work-insights-cloud/blobs
export WORK_INSIGHTS_BIND_ADDR=127.0.0.1:8089
```

For Stage 3 with local AI, also export:

```bash
export WORK_INSIGHTS_AI_BASE_URL=http://127.0.0.1:11434/v1
export WORK_INSIGHTS_AI_SEGMENT_MODEL=qwen2.5:7b-instruct
export WORK_INSIGHTS_AI_DAILY_MODEL=qwen2.5:14b-instruct
```

Then start the API:

```bash
cd cloud
cargo run -p work-insights-api
```

Health check:

```bash
curl -sf http://127.0.0.1:8089/health
```

Expected response:

```json
{"ok":true}
```

## 4. Optional: start Ollama for Stage 3

Stage 3 requires an OpenAI-compatible gateway. Locally the expected path is Ollama.

Example:

```bash
ollama serve
ollama pull qwen2.5:7b-instruct
ollama pull qwen2.5:14b-instruct
```

If you want a different local model, keep the README commands the same and change:

- `WORK_INSIGHTS_AI_SEGMENT_MODEL`
- `WORK_INSIGHTS_AI_DAILY_MODEL`

Low-data days can still generate deterministic reports without AI.

## 5. Get the local Screenpipe API token

The daemon can run with local API auth enabled. To inspect the token:

```bash
./target/release/screenpipe auth token
```

If you want the daemon to use a specific API key, export it before starting:

```bash
export SCREENPIPE_API_KEY=your-token-here
```

Important:

- the work-insights scheduler now forwards the daemon's local API auth token when it calls the local `/search` API internally
- if you call the daemon API manually with `curl`, include `Authorization: Bearer <token>` if the server rejects anonymous requests

## 6. Start the real Screenpipe daemon with Work Insights enabled

This is the real end-to-end path. No mock local `/search` server is involved.

Example command:

```bash
SCREENPIPE_API_KEY=$(./target/release/screenpipe auth token) \
./target/release/screenpipe record \
  --port 3032 \
  --data-dir $HOME/.screenpipe \
  --disable-audio \
  --disable-vision \
  --disable-keyboard-capture \
  --disable-clipboard-capture \
  --disable-meeting-detector \
  --disable-snapshot-compaction \
  --work-insights-enabled \
  --work-insights-ingest-base-url http://127.0.0.1:8089 \
  --work-insights-ingest-auth-token dev-token \
  --work-insights-sync-interval-secs 10 \
  --debug
```

Notes:

- `--work-insights-enabled` turns on the Stage 1 and Stage 2 loop.
- `--work-insights-ingest-base-url` and `--work-insights-ingest-auth-token` enable Stage 2 uploads.
- the scheduler has a built-in startup delay of about 30 seconds before its first tick.
- if you disable screen/audio capture, Stage 1 can still process existing local data already present in `~/.screenpipe/data`

If you want fresh data for validation, run the daemon with your normal capture settings instead of the reduced example above.

## 7. Validate Stage 1 locally

Watch daemon logs for lines like:

- `work-insights sync scheduler started`
- `work-insights: collecting local rows between ...`
- `work-insights: spooled N atoms to ...`

Check the local spool directory:

```bash
ls -R $HOME/.screenpipe/work-insights
```

You should see:

- `cursor.json`
- one or more `batches/*.jsonl`
- one or more `batches/*.manifest.json`

A manifest should include counts such as:

- `atom_count`
- `input_signal_count`
- `dropped_count`

## 8. Validate Stage 2 upload and cloud ingest

Watch daemon logs for lines like:

- `work-insights: uploaded batch ...`
- `work-insights sync: uploaded N pending batch(es)`

Check local upload markers:

```bash
ls $HOME/.screenpipe/work-insights/uploaded
```

You should see:

- `*.uploaded.json`

Check Postgres:

```bash
docker exec cloud-postgres-1 psql -U work_insights -d work_insights -c "select batch_id,status,atom_count,input_signal_count,created_at,completed_at from sync_batches order by created_at desc limit 10;"
```

```bash
docker exec cloud-postgres-1 psql -U work_insights -d work_insights -c "select count(*) as content_atoms from content_atoms; select count(*) as input_signals from input_signals; select org_id,user_id,device_id,batch_id from ingest_cursors;"
```

Expected:

- at least one `sync_batches` row with `status='completed'`
- `content_atoms` count greater than `0`
- `input_signals` count greater than or equal to `0`
- one `ingest_cursors` row for the configured `org/user/device`

## 9. Generate a Stage 3 daily user report

Stage 3 uses the same bearer token as ingest:

- `Authorization: Bearer dev-token`

Pick a date that already has ingested atoms. Then generate:

```bash
curl -s -X POST \
  -H "Authorization: Bearer dev-token" \
  -H "Content-Type: application/json" \
  http://127.0.0.1:8089/v1/reports/me/daily/generate \
  -d '{"date":"2026-06-10","force":false}'
```

Read the report:

```bash
curl -s \
  -H "Authorization: Bearer dev-token" \
  "http://127.0.0.1:8089/v1/reports/me/daily?date=2026-06-10"
```

Read the timeline:

```bash
curl -s \
  -H "Authorization: Bearer dev-token" \
  "http://127.0.0.1:8089/v1/reports/me/timeline?date=2026-06-10"
```

Read one evidence item:

```bash
curl -s \
  -H "Authorization: Bearer dev-token" \
  "http://127.0.0.1:8089/v1/reports/me/evidence/<atom_id>"
```

If the day has little or no evidence, Stage 3 can still return a deterministic low-data report without an AI call.

## 10. Validate Stage 3 in Postgres

Check generated reports:

```bash
docker exec cloud-postgres-1 psql -U work_insights -d work_insights -c "select report_date,status,model,prompt_version,generated_at from user_reports order by generated_at desc limit 10;"
```

Check timeline segments:

```bash
docker exec cloud-postgres-1 psql -U work_insights -d work_insights -c "select report_date,segment_id,start_time,end_time,atom_count,input_signal_count from timeline_segments order by created_at desc limit 20;"
```

Check agent runs:

```bash
docker exec cloud-postgres-1 psql -U work_insights -d work_insights -c "select run_type,status,model,prompt_version,created_at from agent_runs order by created_at desc limit 20;"
```

Expected:

- one `user_reports` row for the requested user/date
- `timeline_segments` rows for the same date
- `agent_runs` rows if the day was not handled by the deterministic low-data path

## End-to-end success criteria

You can say Stage 1, 2, and 3 are working locally when all of these are true:

1. the daemon starts and logs `work-insights sync scheduler started`
2. Stage 1 writes `cursor.json`, `*.jsonl`, and `*.manifest.json`
3. Stage 2 writes `*.uploaded.json`
4. `sync_batches.status='completed'` exists in Postgres
5. `content_atoms` contains ingested rows
6. `POST /v1/reports/me/daily/generate` succeeds for a date with data
7. `GET /v1/reports/me/daily` returns a stored report

## Troubleshooting

### `/search` request fails with a 400

The work-insights local client now URL-encodes timestamps correctly. If you still hit this, the daemon logs should show:

- the full request URL
- the HTTP status
- the response body
- a hint when the query string was rejected

This was previously caused by raw RFC3339 timestamps with `+00:00` being sent without percent-encoding.

### Stage 1 works but Stage 2 uploads fail

Check:

- the cloud API is actually listening on `127.0.0.1:8089`
- `WORK_INSIGHTS_INGEST_TOKEN` matches `--work-insights-ingest-auth-token`
- Postgres is up from `cloud/docker-compose.yml`

Quick checks:

```bash
curl -sf http://127.0.0.1:8089/health
```

```bash
ss -ltnp | rg ':8089\\b'
```

### Stage 3 generation fails

Check:

- there is already ingested data for the requested date
- the cloud API has `WORK_INSIGHTS_AI_*` env vars set correctly
- Ollama is running if you expect AI-backed reports

If the AI gateway returns malformed JSON, Stage 3 records failed `agent_runs` and returns an error instead of silently accepting bad output.

### No Stage 1 batches appear

Check:

- the daemon was started with `--work-insights-enabled`
- at least 30 seconds elapsed after startup
- local Screenpipe data exists for the selected time window
- the daemon logs do not show `work-insights sync: local run failed: ...`

## Source references

- Stage 1 local client and orchestration: [mod.rs](/home/jayshiai/Projects/2os/capture/screenpipe/crates/screenpipe-core/src/work_insights/mod.rs)
- daemon scheduler wiring: [work_insights_sync.rs](/home/jayshiai/Projects/2os/capture/screenpipe/crates/screenpipe-engine/src/work_insights_sync.rs)
- daemon startup integration: [screenpipe-engine.rs](/home/jayshiai/Projects/2os/capture/screenpipe/crates/screenpipe-engine/src/bin/screenpipe-engine.rs)
- cloud API: [main.rs](/home/jayshiai/Projects/2os/capture/screenpipe/cloud/crates/work-insights-api/src/main.rs)
- Stage 3 report pipeline: [reports.rs](/home/jayshiai/Projects/2os/capture/screenpipe/cloud/crates/work-insights-api/src/reports.rs)
- implementation plan: [work-insights-platform-plan.md](/home/jayshiai/Projects/2os/capture/screenpipe/docs/work-insights-platform-plan.md)
