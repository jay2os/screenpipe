# Work Insights Cloud

Portable cloud ingest for Screenpipe work-insights.

## Local Development

```bash
cd cloud
docker compose up -d
export WORK_INSIGHTS_DATABASE_URL=postgres://work_insights:work_insights@localhost:55432/work_insights
export WORK_INSIGHTS_INGEST_TOKEN=dev-token
export WORK_INSIGHTS_DEFAULT_ORG_ID=org_dev
export WORK_INSIGHTS_DEFAULT_USER_ID=user_dev
export WORK_INSIGHTS_DEFAULT_DEVICE_ID=dev_dev
export WORK_INSIGHTS_BLOB_DIR=$HOME/.screenpipe/work-insights-cloud/blobs
export WORK_INSIGHTS_AI_BASE_URL=http://localhost:11434/v1
export WORK_INSIGHTS_AI_SEGMENT_MODEL=qwen2.5:7b-instruct
export WORK_INSIGHTS_AI_DAILY_MODEL=qwen2.5:14b-instruct
cargo run -p work-insights-api
```

The blob directory defaults to `~/.screenpipe/work-insights-cloud/blobs` and
should stay outside the repository.

## Stage 3 Daily Reports

User-level daily report generation is available through a manual endpoint:

- `POST /v1/reports/me/daily/generate`
- Body: `{ "date": "YYYY-MM-DD", "force": false }`
- `GET /v1/reports/me/daily?date=YYYY-MM-DD`
- `GET /v1/reports/me/timeline?date=YYYY-MM-DD`
- `GET /v1/reports/me/evidence/:atom_id`

The report pipeline uses an OpenAI-compatible AI gateway contract. Local
development is expected to point at Ollama or another local compatible server.
Production can point at Azure AI Foundry or another provider behind the same
HTTP shape.

## EOD Scheduling

Stage 3 does not run an internal scheduler yet. The intended EOD path is:

1. local Screenpipe sync uploads the final batch for the day
2. an external scheduler or job runner calls `POST /v1/reports/me/daily/generate`
3. org-level reducers will later consume stored `user_reports`

Keeping generation behind one endpoint gives us a stable seam for cron, queue,
or workflow orchestration without duplicating report logic.
