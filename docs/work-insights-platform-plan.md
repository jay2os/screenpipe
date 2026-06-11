# Portable Screenpipe Work Insights Platform

## Summary

Build a portable, non-EE work-insights system on top of Screenpipe's existing local capture/search APIs. The system syncs cleaned, deduplicated **content atoms** and lightweight input signals from local Screenpipe to a cloud analysis layer, generates evidence-backed daily user reports, then aggregates those into org-level management insights.

Architecture rule: **portable core, Azure by adapter**. No EE code is used or copied.

Default decisions:

- Cloud receives processed content atoms and lightweight input signals, not raw screenshots or raw audio files.
- v1 people tracking uses processed local text atoms only, with no connected comms/calendar ingestion.
- Reports optimize for evidence-backed insights.
- Daily EOD reports are the first production cadence.
- Managers see aggregates first, with policy-controlled redacted drilldown.
- Raw capture remains local and complete; only the analysis/sync path filters noise.

## Implementation Stages

### Stage 1: Local orchestration and cleaning

Implemented in `screenpipe-core` as a local-only stage that:

- Polls the local Screenpipe API for timestamp-bearing rows.
- Cleans and deduplicates them into content atoms.
- Uses `/search?content_type=ocr` as the primary screen-text feed because it is Screenpipe's consolidated frame-level text surface, not raw OCR-only text.
- Treats local audio transcripts as text atoms when available.
- Preserves local input actions as lightweight signals for later segment grouping.
- Persists a local cursor for incremental runs.
- Spools newline-delimited batches and manifests to disk for later upload.
- Keeps the local `/elements` client available for metadata enrichment, but does not require it for the timeline source.

Stage 1 does not include cloud upload, report generation, org/user reducers, or dashboard/UI work.

Current ambiguity resolved in this stage:

- `/elements` is useful for role, bounds, depth, source, and `on_screen`, but it does not return timestamps, so it cannot be the sole timeline source.
- `/search?content_type=ocr` returns consolidated frame text from `frames.full_text`, with `text_source` preserving whether capture used accessibility, OCR fallback, or hybrid extraction.
- `AudioContent` is not a raw audio payload. Stage 1 only uses its transcription/text metadata and does not upload the audio file path as evidence.
- `InputContent` is useful context, but it remains an action signal and is not scored as a text atom.
- Local user/org/device IDs are not guaranteed by the local API, so Stage 1 keeps them optional instead of inventing placeholder identities.

### Stage 2: Cloud ingest and durable storage

Completed. The cloud ingestion path now exists end to end:

- Add upload ticket / batch ingest plumbing.
- Upload the local JSONL spools to the portable cloud adapter.
- Archive uploaded JSONL batches in blob storage.
- Queue blob-pointer ingest jobs for asynchronous processing.
- Persist normalized atoms, input signals, batch manifests, and cursors in the cloud store from `work-insights-db-worker`.
- Add idempotent upload completion handling and retry semantics.

Pending validation:

- Run a live end-to-end smoke with the engine process once the unrelated native `antirez-asr-sys` build issue is resolved.
- Confirm a real local batch moves from `screenpipe-core` spool -> `work-insights-api` upload -> blob archive -> queue -> `work-insights-db-worker` -> Postgres rows.

### Stage 3: Daily report generation

User-level daily reports are now implemented in the cloud MVP:

- Deterministic prepass.
- Segment extraction.
- Daily user reducer.
- Evidence-backed report views.

Still deferred:

- Org reducer.
- Manager/org aggregation APIs.
- Internal EOD scheduler. Current scheduling seam is the external `work-insights-report-runner generate-daily` job.

## Architecture

- **Local capture**
  - Keep Screenpipe capture unchanged.
  - Use existing local APIs:
    - `/search` for screen, input, audio-compatible records.
    - `/elements` for role/bounds/on-screen-aware text extraction.
    - `/activity-summary` for app/window usage and high-level local stats.
    - `/memories` only if enabled later; not required for v1.
  - Do not read SQLite directly in v1.

- **Local orchestrator**
  - New OSS-side module/service, separate from EE.
  - Polls local APIs every 5 minutes.
  - Builds content atoms from `/search`; keeps `/elements` available for later enrichment.
  - Stores local cursors by stream and timestamp.
  - Spools JSONL batches locally in Stage 1; uploads through portable interfaces in Stage 2.
  - Uses `crates/screenpipe-sync` only for generic primitives: cursor, JSONL, blob destination, ticketed upload if needed.

- **Portable cloud core**
  - Core interfaces:
    - `RecordStore`
    - `BlobStore`
    - `JobQueue`
    - `Scheduler`
    - `AiClient`
    - `AuthProvider`
    - `ReportStore`
  - Cloud lives in its own Rust workspace under `cloud/`, excluded from the root Screenpipe workspace so deps, binaries, and release cadence stay isolated while still living in one repo.
  - Cloud deployable processes live under `cloud/services/<service-name>`.
  - Cloud reusable domain, storage, and infrastructure logic lives under `cloud/crates/<crate-name>`.
  - Service crates should stay thin: process startup, config, routes or worker loops, and calls into library crates.
  - Infrastructure adapters are selected by env-driven factories in the crate that owns the interface, e.g. `blob_store_from_env()` and `queue_from_env()`. Service crates should not switch on provider-specific details directly.
  - Current services:
    - `cloud/services/ingest-api`: public HTTP ingest and report-read API.
    - `cloud/services/db-worker`: private queue consumer that writes uploaded batches to Postgres.
    - `cloud/services/report-runner`: scheduled daily report generator.
  - Shared DTOs live in a separate `crates/screenpipe-protocol` crate only if local and cloud sides truly need the exact same wire shapes. DTO means a plain Data Transfer Object: a serializable struct/schema with no business logic. Do not create the crate preemptively.
  - Azure adapter:
    - PostgreSQL for records/reports.
    - Blob Storage for immutable batch archive.
    - Service Bus for ingest/report queues.
    - Container Apps or Jobs for workers.
    - Azure AI Foundry/OpenAI-compatible model endpoint for AI.
  - Local adapter:
    - Docker Compose Postgres.
    - Filesystem blob store.
    - In-memory or Redis queue.
    - Ollama/OpenAI-compatible AI endpoint.

## Data Flow

```text
Screenpipe capture
-> local SQLite
-> local /search + /elements + /activity-summary
-> content atom extractor
-> local sync batch
-> cloud ingest
-> blob archive + ingest queue
-> db worker
-> normalized records
-> deterministic timeline segmentation
-> segment extraction agents
-> daily user reducer
-> org reducer
-> user/manager UI
```

## Content Atom Extraction

Existing Screenpipe already has partial dedup/noise logic:

- Thin accessibility detection for chrome-heavy trees.
- Frame `content_hash` / `simhash`.
- `/search` OCR/UI same-moment dedup.
- `/activity-summary` representative snippet sampling.
- `/elements?on_screen=true`.

New work: add a dedicated **content atom extraction layer** for reports.

- Prefer `/search?content_type=ocr` rows for Stage 1 local orchestration because this is the consolidated frame-level screen-text surface.
- Preserve OCR row `text_source` so atoms can distinguish accessibility-derived, OCR fallback, and hybrid screen text.
- Include `/search` audio transcript rows as content atoms when transcripts are available. These are transcript text plus audio metadata, not raw audio upload.
- Include `/search` input rows as lightweight input signals. These remain action/event signals and are grouped with nearby atoms during segmentation instead of being scored as content atoms.
- Do not separately query `/search?content_type=accessibility` in Stage 1 unless future enrichment needs its narrower accessibility-only semantics.
- Keep `/elements` as the future higher-fidelity path for bounds/role/depth/on-screen extraction once orchestration needs it.
- Do not modify raw capture or search behavior.

Atom scoring:

```text
score =
  role_score
+ layout_score
+ novelty_score
+ semantic_score
+ focus_score
- chrome_penalty
- repetition_penalty
```

Rules:

- Drop very short generic UI labels: `Home`, `Search`, `Settings`, `Cancel`, `Share`, `New`, `File`, `Edit`, `View`.
- Penalize toolbar/menu/button/tab/sidebar/status-bar roles.
- Boost document/editor/text area/web content/terminal-like roles.
- Boost central, large, on-screen content.
- Boost changed/new text compared to nearby prior frames.
- Boost errors, todos, file paths, ticket IDs, PRs, repo names, decisions, names, and dates.
- Collapse repeated text across adjacent frames into one atom with `first_seen`, `last_seen`, and `seen_count`.
- Maintain per-app chrome phrase cache for text repeated across many unrelated windows.

Atom schema:

```json
{
  "id": "stable_hash",
  "org_id": "org_...",
  "user_id": "user_...",
  "device_id": "dev_...",
  "frame_id": 123,
  "timestamp": "2026-06-09T10:30:00Z",
  "app_name": "VS Code",
  "window_name": "auth.ts",
  "browser_url": null,
  "text": "Type error: property userId does not exist...",
  "role": "AXTextArea",
  "bounds": {"left": 0.22, "top": 0.14, "width": 0.72, "height": 0.78},
  "score": 0.91,
  "reasons": ["content_role", "central", "changed", "error_like"],
  "first_seen": "2026-06-09T10:29:40Z",
  "last_seen": "2026-06-09T10:31:10Z",
  "seen_count": 4
}
```

`frame_id` is optional because audio transcript atoms do not originate from a screen frame. Screen/accessibility/OCR atoms keep it when the local API provides it.

Input signal schema:

```json
{
  "id": "stable_hash",
  "timestamp": "2026-06-09T10:30:12Z",
  "frame_id": 123,
  "event_type": "click",
  "app_name": "Chrome",
  "window_title": "Linear",
  "browser_url": "https://linear.app/...",
  "text_content": "AUTH-123",
  "element_role": "button",
  "element_name": "Open issue"
}
```

Input signals are not uploaded as raw keyboard/mouse telemetry for behavioral surveillance. They are retained as coarse local evidence for later segment reconstruction: what action happened near which screen/audio atoms.

Only atoms above the configured score threshold are sent to analysis by default. Low-score atoms can be retained locally for debugging but not uploaded.

## Cloud Storage

Core tables:

- `sync_batches`
  - Batch metadata, checksums, cursors, counts, upload mode, status.
- `content_atoms`
  - Deduped analysis records with evidence refs.
- `timeline_segments`
  - Deterministic day slices built from atom continuity.
- `entities`
  - Projects, tools, documents, URLs, tickets, people mentions, errors.
- `blockers`
  - Software/person/process blocker candidates with confidence and evidence.
- `automation_opportunities`
  - Repeated workflows and inefficiency patterns.
- `agent_runs`
  - Model, prompt version, input/output token counts, status, errors, cost metadata.
- `user_reports`
  - Daily report JSON, markdown, evidence refs, generated_at, model provenance.
- `org_reports`
  - Aggregate team/org report JSON, markdown, blocker trends, automation opportunities.

Retention defaults:

- Content atoms: 30 days.
- Reports and aggregate metrics: 1 year.
- Blob archive: 30 days unless customer policy changes it.

## Report Generation

### 1. Deterministic Prepass

Run before any LLM call.

Inputs:

- Content atoms.
- App/window/browser usage from local summary and cloud atoms.
- Timestamp continuity.
- Repetition/change stats.

Outputs:

- Timeline segments.
- Candidate topics/projects.
- Candidate blockers.
- Candidate people mentions.
- Candidate inefficient workflows.

Segmenting rules:

- Group atoms by user, day, app/window/browser, and temporal proximity.
- Default segment size: 5-15 active minutes.
- Merge adjacent segments when app/window/topic stays stable.
- Split on major app switch, meeting/chat context, error burst, or long idle gap.

### 2. Segment Extraction Agent

Each segment agent receives bounded atoms, not raw full-day text.

Default caps:

- Max segment input: 8k tokens.
- Max segment output: 1k tokens.
- Max segments per user/day: 80.
- Overflow is summarized deterministically before agent processing.

Agent output JSON:

```json
{
  "segment_id": "seg_...",
  "time_range": {"start": "...", "end": "..."},
  "activity": "Debugged auth userId type mismatch",
  "project_or_topic": "auth service",
  "tools_used": ["VS Code", "Chrome"],
  "accomplishments": [],
  "blockers": [
    {
      "type": "software",
      "summary": "TypeScript userId mismatch blocked build",
      "confidence": 0.86,
      "evidence_atom_ids": ["atom_1", "atom_2"]
    }
  ],
  "inefficiencies": [
    {
      "type": "troubleshooting_loop",
      "summary": "Repeated switching between editor, docs, and error output",
      "confidence": 0.72,
      "evidence_atom_ids": ["atom_3", "atom_4"]
    }
  ],
  "people_mentions": [
    {
      "display_name": "Alex",
      "context": "PR review or chat thread",
      "confidence": 0.61,
      "evidence_atom_ids": ["atom_5"]
    }
  ]
}
```

### 3. Daily User Reducer

The daily reducer reads segment outputs and selected evidence expansions.

Report sections:

- Summary.
- What the user did.
- Accomplishments.
- Unfinished work / todos.
- Software blockers.
- Person/process blockers.
- Inefficiencies.
- Automation/AI opportunities.
- People interacted with or mentioned.
- Evidence-backed timeline.

Rules:

- Every claim needs evidence refs.
- Claims without enough support are downgraded to "possible".
- No fabricated people, blockers, tasks, or durations.
- Person names from screen text remain ambiguous unless repeated/coherent evidence links them.

### 4. Org Reducer

The org reducer reads user reports first, not raw atoms.

Outputs:

- Common blockers.
- Repeated workflow inefficiencies.
- Team focus areas.
- Automation opportunities.
- Cross-user collaboration load.
- Users/teams affected, subject to manager visibility policy.

Manager drilldown:

- Default view is aggregate.
- Drilldown shows redacted evidence snippets only when org policy allows.
- Every drilldown is audit logged.

## People Tracking

v1 source: **screen text only**.

Extract people from:

- Visible chat/email/PR/comment names.
- Window titles.
- Browser page titles.
- Assignment/reviewer labels.
- Phrases like "waiting on Alex", "blocked by approval", "needs review from Priya".

Entity policy:

- Store `person_mentions`, not canonical people, on first sighting.
- Merge mentions only when repeated evidence supports it.
- Do not call Slack/Gmail/Teams/calendar APIs in v1.
- Do not infer private identity beyond visible text.
- Show uncertainty in reports when identity is ambiguous.

## Blocker And Inefficiency Detection

Software blockers:

- Error messages.
- Failed builds/tests.
- Permission/login failures.
- Repeated docs/search visits around one issue.
- Stuck loading/retry states.
- Repeated terminal/editor error loops.

Person/process blockers:

- Waiting/review/approval language.
- Visible PR review states.
- Comments assigning work to another person.
- Chat/email snippets indicating dependency.

Inefficiencies:

- High context switching.
- Repeated app transitions.
- Repeated copy/paste or form-filling patterns when UI/input events are available.
- Long troubleshooting loops.
- Manual status/report generation.
- Repeated use of the same prompt/search/workflow.

## AI Models And Cost Controls

Default model routing:

- Deterministic prepass: no LLM.
- Segment extraction: `gpt-5-nano`.
- Segment verifier: `gpt-5-nano` or local small model.
- Daily user reducer: `gpt-5-mini`.
- Org reducer: `gpt-5-mini`.
- Escalation/audit only: `gpt-5`.
- Local dev: Ollama/OpenAI-compatible adapter.

Cost controls:

- Never send raw full-day text to `gpt-5-mini` or `gpt-5`.
- Segment agents read only content atoms.
- Store segment outputs and rerun only when atom hash, prompt version, or model version changes.
- Track token usage in `agent_runs`.
- Enforce per-user/day token budgets.
- Use batch processing for EOD jobs where available.

Typical target:

- Normal user/day: about 500k nano input, 50k nano output, 80k mini input, 5k mini output.
- Approximate expected cost: `$0.05-$0.20` per active user/day before batch discounts, assuming OpenAI public pricing as of June 9, 2026.
- Batch processing can reduce cost where supported.

Pricing references:

- OpenAI API pricing: https://openai.com/api/pricing/
- Azure AI Foundry model platform: https://azure.microsoft.com/en-us/products/ai-foundry/models/

## Public Interfaces

Local orchestrator config:

```json
{
  "api_base_url": "http://localhost:3030",
  "sync_interval_secs": 300,
  "lookback_secs": 900,
  "overlap_secs": 90,
  "page_size": 200,
  "atom_threshold": 0.55,
  "max_atoms_per_batch": 1000,
  "include_audio_transcripts": true,
  "include_input_signals": true,
  "include_low_score_atoms": false,
  "spool_dir": "~/.screenpipe/work-insights"
}
```

Cloud ingest:

- `POST /v1/ingest/batches`
- `POST /v1/ingest/upload-ticket`
- `POST /v1/ingest/upload-complete`

User APIs:

- `GET /v1/reports/me/daily?date=YYYY-MM-DD`
- `GET /v1/reports/me/timeline?date=YYYY-MM-DD`
- `GET /v1/reports/me/evidence/:id`

Manager APIs:

- `GET /v1/org/reports/daily?date=YYYY-MM-DD`
- `GET /v1/org/blockers?date=YYYY-MM-DD`
- `GET /v1/org/automation-opportunities?date=YYYY-MM-DD`
- `GET /v1/org/users/:user_id/reports/daily?date=YYYY-MM-DD`

Admin/config APIs:

- `GET/PUT /v1/org/policies`
- `GET /v1/org/devices`
- `GET /v1/org/agent-runs`

## UI

User report view:

- Daily summary.
- Timeline.
- Blockers.
- Todos.
- Inefficiencies.
- Automation suggestions.
- People mentions.
- Evidence drilldown.

Manager view:

- Org summary.
- Common blockers.
- Team workflow inefficiencies.
- Automation opportunities.
- Aggregate people/process bottlenecks.
- User drilldown only when allowed.

## Test Plan

- **Content atom tests**
  - Toolbar/menu/sidebar text is dropped or downweighted.
  - Central document/editor text is kept.
  - Repeated chrome collapses.
  - Repeated content across adjacent frames collapses with `seen_count`.
  - `on_screen=false` elements are ignored by default.
  - Short but important text like ticket IDs/errors is preserved.

- **Sync tests**
  - Cursor advances only after successful upload.
  - Duplicate batch upload is idempotent.
  - Local API failure retries without skipping data.
  - JSONL schema is stable and versioned.

- **Agent fixture tests**
  - Coding day with build errors.
  - Sales/support day with many names.
  - Chat-heavy day with ambiguous people.
  - Repeated manual workflow day.
  - Low-data day.
  - Noisy-sidebar-heavy day.

- **Report quality tests**
  - Every claim has evidence refs.
  - Unsupported blockers are not emitted as facts.
  - Ambiguous people are not over-merged.
  - Automation suggestions reference observed workflows.

- **Scale tests**
  - 100, 1,000, and 10,000 active-user synthetic EOD runs.
  - Queue backpressure.
  - Token budget enforcement.
  - Report rerun cache hit behavior.

- **Security/RBAC tests**
  - User can read only own report.
  - Manager aggregate access works.
  - Manager drilldown policy is enforced.
  - Evidence access is audit logged.
  - Redaction policy is applied before manager drilldown.

## Plan Audit

Resolved gaps:

- EE dependency removed; implementation uses new OSS-side orchestration.
- Azure is adapter-only; core design remains portable.
- Report generation is now concrete: deterministic prepass, segment extraction, daily reducer, org reducer.
- Screen-noise handling is explicit through content atoms.
- People tracking is constrained to screen text only for v1.
- Cost scaling is bounded by model routing, token caps, and caching.
- Stage 2 is complete: cloud ingest, durable storage, and engine-side scheduler wiring are in place.

Remaining risks and mitigations:

- **Atom quality risk:** deterministic filters may drop useful sidebar content.
  - Mitigation: keep sampled low-score atoms locally, tune thresholds with fixtures, and allow per-app overrides.
- **People ambiguity risk:** screen-text-only names can collide.
  - Mitigation: store mentions separately and require repeated evidence before merging.
- **Report hallucination risk:** LLM may infer beyond evidence.
  - Mitigation: strict JSON schema, evidence refs required, verifier pass, confidence labels.
- **Cost overrun risk:** heavy text users can exceed expected token budgets.
  - Mitigation: hard segment caps, deterministic overflow summaries, per-user/day budgets, batch jobs.
- **Privacy/trust risk:** manager drilldown can feel invasive.
  - Mitigation: aggregate-first UI, redacted evidence, policy controls, audit logs.
- **Portability drift risk:** Azure-specific assumptions can leak into core code.
  - Mitigation: provider interfaces first, local adapter tests required for every cloud feature.
- **Evaluation gap:** real-world quality depends on representative screen-text fixtures.
  - Mitigation: create an eval suite before production rollout and treat it as a release gate.
- **Build validation gap:** the engine crate's full test/build path is currently blocked by an unrelated native dependency failure in `antirez-asr-sys`.
  - Mitigation: keep work-insights scoped tests green; rerun the full engine smoke once that dependency is fixed upstream or locally.

## Assumptions

- v1 does not use EE code.
- v1 does not require connected comms APIs, calendar, screenshots, or raw audio files.
- v1 can use local audio transcript text and local input action records when available.
- v1 syncs only processed content atoms, lightweight input signals, and evidence IDs.
- Raw Screenpipe capture remains local and complete.
- `cloud/` is a separate Rust workspace, not a `crates/*` member of the root workspace.
- `crates/screenpipe-protocol` is optional and should exist only when local/cloud DTO sharing becomes real, not hypothetical.
- Model names and prices are configurable because provider pricing changes.
