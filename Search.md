# Search Flow

This document explains the local search/retrieval module for future agents. It builds on `Flow.md`: capture writes screen/audio/input/meeting data into SQLite, and `/search` is the main API surface that retrieves that captured data for the app, pipes, MCP, CLI, and external callers.

## What Search Does

`GET /search` is the unified retrieval endpoint for captured local history. It returns a paginated list of tagged content items from:

- Screen text from `frames` / `ocr_text` / `frames_fts`.
- Accessibility-derived screen text stored on `frames`.
- Audio transcriptions from `audio_transcriptions`.
- Live meeting transcript rows from `meeting_transcript_segments`.
- User input/action events from `ui_events`.
- Memories from the memories APIs when `content_type=memory`.

Route registration is in `crates/screenpipe-engine/src/server.rs`.

Primary route implementation is `crates/screenpipe-engine/src/routes/search.rs`.

DB implementation is mainly `crates/screenpipe-db/src/db.rs`.

Public response shapes are in `crates/screenpipe-engine/src/routes/content.rs`.

Internal DB result types and `ContentType` are in `crates/screenpipe-db/src/types.rs`.

## API Surface

Main routes:

- `GET /search`: unified search over capture data.
- `GET /search/keyword`: screen keyword search with text positions / grouping.
- `GET /elements`: structured OCR/accessibility element search, adjacent to search but implemented as its own route.
- `screenpipe search`: CLI equivalent that opens SQLite directly and emits the same `ContentItem` shape.

Common examples:

```bash
curl "http://localhost:3030/search?limit=20&content_type=all"
curl "http://localhost:3030/search?q=deployment&app_name=Slack&limit=20"
curl "http://localhost:3030/search?content_type=audio&speaker_name=Sarah&limit=20"
curl "http://localhost:3030/search?browser_url=github.com&limit=20"
curl "http://localhost:3030/search?start_time=2026-05-14T09:00:00Z&end_time=2026-05-14T12:00:00Z&limit=50"
curl "http://localhost:3030/search/keyword?query=invoice&group=true&limit=100"
```

Important path note: the endpoint is `/search`, not `/api/search`.

## Query Parameters

`SearchQuery` is defined in `crates/screenpipe-engine/src/routes/search.rs`.

Core parameters:

- `q`: text query. Empty or omitted means "latest results" subject to filters.
- `content_type`: `all`, `ocr`, `audio`, `input`, `accessibility`, or `memory`.
- `limit`: page size, default `20`.
- `offset`: page offset, default `0`.
- `start_time`, `end_time`: flexible datetimes parsed by `routes/time.rs`.
- `app_name`, `window_name`, `frame_name`: screen/app filters.
- `browser_url`: frame URL filter; forces frame/OCR search.
- `focused`: frame focus filter; forces frame/OCR search.
- `device_name`: device filter for screen/audio rows.
- `machine_id`: synced-machine filter for applicable local rows.
- `speaker_ids`: comma-separated audio speaker ids.
- `speaker_name`: case-insensitive partial speaker label/name filter.
- `min_length`, `max_length`: text/transcript length filters.
- `on_screen`: for accessibility searches, restricts to accessibility elements that were actually visible in the captured screenshot.
- `include_frames`: if true, OCR results include base64 frame extraction.
- `max_content_length`: middle-truncates text fields in the response.
- `filter_pii`: runs returned text through the privacy filter before returning.
- `include_cloud`: currently influences returned cloud metadata; local result query remains local.

Bool parsing is forgiving: `true/false`, `1/0`, `yes/no`, `on/off`, and empty-as-false for non-optional booleans.

Comma-separated parsing:

- `speaker_ids=1,2,3`
- `/search/keyword` uses `app_names=Slack,Chrome`

## Response Shape

`SearchResponse` in `routes/search.rs`:

```json
{
  "data": [
    { "type": "OCR", "content": {} },
    { "type": "Audio", "content": {} },
    { "type": "Input", "content": {} }
  ],
  "pagination": {
    "limit": 20,
    "offset": 0,
    "total": 123
  },
  "cloud": null
}
```

The tagged enum is `ContentItem` in `crates/screenpipe-engine/src/routes/content.rs`.

Variants:

- `OCR`: screen/frame result. Historically named OCR, but `content.text_source` tells whether the text came from accessibility (`accessibility`), OCR fallback (`ocr`), or hybrid/legacy.
- `Audio`: background or live transcript result.
- `UI`: deprecated accessibility traversal shape. In current flow, accessibility screen text is frame-backed.
- `Input`: user input/action event from `ui_events`.
- `Memory`: persistent memory row.

## Route-Level Flow

`search` handler in `crates/screenpipe-engine/src/routes/search.rs`:

1. Parses query params into `SearchQuery`.
2. Applies pipe permissions. If the request has `PipePermissions.privacy_filter=true`, it forces `filter_pii=true`.
3. Computes a cache key from all query parameters that affect results.
4. Returns a cached response when possible. Cache is skipped for `include_frames=true`.
5. Runs DB search and DB count in parallel with a 30-second timeout:
   - `DatabaseManager::search(...)`
   - `DatabaseManager::count_search_results(...)`
6. Filters out rows where app name contains `screenpipe`.
7. Converts internal `SearchResult` rows into public `ContentItem` via `search_result_to_content_item`.
8. Deduplicates matching `OCR` and deprecated `UI` rows at the same second and same app.
9. If `filter_pii=true`, redacts returned text fields using `privacy_filter::global().filter_batch`.
10. If `include_frames=true`, extracts frame images for OCR results using `video_utils::extract_frame`.
11. Emits analytics.
12. Adds cloud-search metadata when available/requested.
13. Stores non-frame response in the search cache.

Timeout behavior:

- DB search and count are wrapped in a 30-second timeout.
- Timeout returns HTTP `408` with guidance to narrow time range or add filters.
- DB errors return HTTP `500`.
- Privacy filter failure returns HTTP `503` and fails closed rather than leaking raw text.

## DB Dispatch

`DatabaseManager::search` is in `crates/screenpipe-db/src/db.rs`.

It dispatches based on `ContentType`:

- `All`: fans out to screen/OCR, audio, and accessibility queries. It fetches `limit + offset` per source, merges, sorts by timestamp descending, then applies global pagination.
- `OCR`: `search_ocr`.
- `Audio`: `search_audio`.
- `Accessibility`: `search_accessibility` or `search_accessibility_visible` when `on_screen` is set.
- `Input`: `search_ui_events`.
- `Memory`: `list_memories`.

Special dispatch rules:

- If `focused` or `browser_url` is set, `content_type` is forced to `OCR` because those filters are frame-specific.
- `Audio` is skipped when app/window filters are present because audio rows do not have app/window context.
- For `All`, if app/window/frame filters are present, audio is not searched.
- Final merged results are sorted by timestamp descending.

`DatabaseManager::count_search_results` mirrors dispatch so pagination totals match visible results.

## Screen Search

Main method: `search_ocr` in `crates/screenpipe-db/src/db.rs`.

Data sources:

- `frames`
- `ocr_text`
- `video_chunks`
- `vision_tags`
- `tags`
- `frames_fts`

Search behavior:

- Uses `frames_fts` when `q`, `app_name`, `window_name`, or `browser_url` are present.
- Builds one combined FTS5 query from text query plus column-specific FTS filters.
- Uses SQL filters for timestamp, length, device, machine, focus, and frame name.
- Returns `COALESCE(frames.full_text, ocr_text.text, frames.accessibility_text, '')`.
- Returns `COALESCE(frames.snapshot_path, video_chunks.file_path)` as the frame media path.
- Uses a heavy-read semaphore to limit concurrent large screen-text reads and avoid starving capture writes.

Why `OCR` results may be accessibility:

- Current capture stores accessibility-first text in `frames.full_text` and `frames.accessibility_text`.
- OCR fallback text is still in `ocr_text`.
- The result type remains `OCR` for API compatibility.
- Consumers should inspect `content.text_source`.

## Accessibility Search

Default method: `search_accessibility` in `crates/screenpipe-db/src/db.rs`.

Default accessibility search:

- Reads `frames`.
- Uses `frames_fts` for text/app/window filters.
- Requires `frames.accessibility_text IS NOT NULL AND != ''`.
- Returns the deprecated `UI` shape from DB, later converted to `ContentItem::UI`.

Visible-only method: `search_accessibility_visible`.

Visible accessibility search:

- Reads `elements` joined to `frames`.
- Optionally joins `elements_fts`.
- Filters `elements.source = 'accessibility'`.
- Filters `elements.on_screen = 1` or `0`.
- Groups by frame id to preserve existing API shape.

Use `content_type=accessibility&on_screen=true` when a caller needs text that was visually present, not text from a hidden scroll buffer or off-screen accessibility tree nodes.

## Audio Search

Main method: `search_audio` in `crates/screenpipe-db/src/db.rs`.

It merges two sources:

- Background audio: `search_background_audio`
- Live meeting transcripts: `search_live_meeting_transcripts`

Background audio source tables:

- `audio_transcriptions`
- `audio_chunks`
- `speakers`
- `audio_tags`
- `tags`
- `audio_transcriptions_fts`
- diarization tables for provider labels and confidence

Background behavior:

- Uses `audio_transcriptions_fts` when `q` is non-empty.
- Filters by timestamp, text length, speaker ids, speaker name, device, and machine.
- Excludes hallucinated speakers.
- Excludes cloud placeholder audio paths (`cloud://%`).
- Returns speaker object when `speaker_id` is known.
- Falls back to diarization provider labels when no global speaker exists.

Live meeting behavior:

- Reads `meeting_transcript_segments`.
- Uses `LIKE` search, not FTS.
- Returns negative `chunk_id` (`-segment_id`) to avoid collision with audio chunk ids.
- Uses `live://meeting/{meeting_id}/transcript/{segment_id}` as file path.
- Adds tags `meeting` and `live`.
- Marks `source="live"`.
- Currently skips live results when `machine_id` is set or non-empty `speaker_ids` are provided.

Audio result shape:

- `transcription` and `text` are the same value.
- `source` can be background/live/diarization mode.
- `speaker_label`, `speaker_source`, `speaker_confidence`, and `speaker_provisional` help clients display speaker identity even before a global speaker is assigned.

## Input Search

Method: `search_ui_events` in `crates/screenpipe-db/src/db.rs`.

Data source:

- `ui_events`

Behavior:

- Searches `text_content`, `app_name`, and `window_title` using `LIKE`.
- Supports exact `event_type` internally, though `/search` passes `None`.
- Filters by app/window/time.
- Returns event metadata, element context, and optional `frame_id`.

Current `/search` does not expose a direct event-type query parameter. If future work needs `event_type=clipboard` or `event_type=click`, the DB method already supports it; the route query struct would need to grow a parameter.

## Memory Search

When `content_type=memory`, `DatabaseManager::search` calls `list_memories`.

The route supports converting `SearchResult::Memory` into `ContentItem::Memory`, but note that other docs/skills in this repo also recommend using `/memories` directly for memory-first workflows. Treat `/search?content_type=memory` as a compatibility path, not the full memory API.

## Keyword Search

Route: `GET /search/keyword`.

Handler: `keyword_search_handler` in `crates/screenpipe-engine/src/routes/search.rs`.

Request type: `KeywordSearchRequest`.

Parameters:

- `query`: required text query. The field is named `query`, not `q`.
- `limit`, `offset`
- `start_time`, `end_time`
- `fuzzy_match`
- `order`: ascending/descending
- `app_names`: comma-separated allowlist
- `group`: boolean

Flat mode:

- Calls `DatabaseManager::search_with_text_positions`.
- Returns a bare JSON array, not `{ data, pagination }`.
- Uses `frames_fts` to find matching frame ids.
- Reads OCR `text_json` to find bounding boxes.
- Falls back to accessibility tree node bounds when OCR positions are unavailable.
- Returns `SearchMatch` rows with `frame_id`, timestamp, app/window/url, text, `text_positions`, confidence, and `text_source`.

Group mode:

- Calls `DatabaseManager::search_for_grouping`.
- Skips large text/text_json columns for speed.
- Caps results per app for diversity.
- Calls `DatabaseManager::cluster_search_matches(filtered, 120)` to merge adjacent hits with the same app/window/url within a 120-second gap.
- Returns grouped search matches.

Use `/search/keyword` when the caller needs a lightweight set of frame hits, text coordinates, or grouped visual sessions. Use `/search` when the caller needs the full multi-modal content payload.

## Search Cache

Route-level cache type:

- `SearchCache = MokaCache<u64, Arc<SearchResponse>>` in `crates/screenpipe-engine/src/server.rs`.

Cache key:

- `compute_search_cache_key` in `routes/search.rs`.
- Includes query, pagination, content type, time filters, app/window/frame filters, speaker filters, browser URL, focus, `on_screen`, truncation, device/machine, cloud flag, and PII flag.

Cache is bypassed when:

- `include_frames=true`, because frame extraction returns binary/base64 payloads and can be expensive/large.

Potential gotcha:

- If adding a new query parameter that changes results, update `compute_search_cache_key` and tests.

## PII Filtering and Pipe Permissions

`filter_pii=true` redacts text-bearing fields in final results:

- OCR `text`
- Audio `transcription`
- UI `text`
- Input `text_content`
- Memory `content`

Implementation is in `crates/screenpipe-engine/src/privacy_filter.rs` and invoked by `routes/search.rs`.

Pipe permissions:

- `OptionalPipePerms` extracts `PipePermissions` from request extensions.
- If a pipe manifest has `privacy_filter: true`, `/search` forces `filter_pii=true`.
- Permission parsing and defaults live in `crates/screenpipe-core/src/pipes/permissions.rs`.

There is also a bash environment shim in `crates/screenpipe-core/src/agents/bash_env.rs` that can rewrite curl calls to `/search` to include `filter_pii=1` when `SCREENPIPE_FILTER_PII=1`.

## Consumers

Known consumers/wrappers:

- HTTP server route: `crates/screenpipe-engine/src/server.rs`.
- Desktop/frontend code: many app features query `/search` through API helpers and hooks in `apps/screenpipe-app-tauri`.
- MCP tool `search-content`: `packages/screenpipe-mcp/src/index.ts`.
- MCP tool `keyword-search`: `packages/screenpipe-mcp/src/index.ts`.
- MCP UI search page: `packages/screenpipe-mcp/ui/search.html`.
- HTTP MCP adapter: `packages/screenpipe-mcp/src/http-server.ts`.
- CLI command: `crates/screenpipe-engine/src/cli/search.rs`.
- Pipe permissions and extension permissions: `crates/screenpipe-core/src/pipes/permissions.rs`, `crates/screenpipe-core/assets/extensions/screenpipe-permissions.ts`.
- Docs and recipes: `docs/mintlify/docs-mintlify-mig-tmp/*.mdx`.

The CLI is important because it deliberately mirrors `GET /search`:

- Opens `~/.screenpipe/db.sqlite` directly.
- Uses `DatabaseManager::search`.
- Uses the same `search_result_to_content_item` converter.
- `--json` emits one `ContentItem` per line, matching the API `data[]` schema.

## Relationship to Other Retrieval Features

Most high-level features either call `/search` directly or use narrower endpoints built on the same tables:

- Chat/AI/MCP tools use `/search` for raw evidence.
- Pipes use `/search` when manifest permissions allow `Api(GET /search)`.
- Meeting views use dedicated meeting endpoints for transcript assembly, but `/search?content_type=audio` also surfaces background and live transcript rows.
- Frame viewers use `/frames/:frame_id`, `/frames/:frame_id/text`, `/frames/:frame_id/context`, often after a `/search` result provides `frame_id`.
- Activity summaries intentionally prefer `/activity-summary` for "what was I doing?" summaries, and fall back/escalate to `/search` for verbatim evidence or specific frame ids.
- Element-level inspection uses `/elements` and `/frames/:frame_id/elements`, not `/search`, when clients need structured node data.

## Performance Notes

- `/search` runs search and count concurrently.
- `/search` has a 30-second timeout.
- Screen/OCR search uses a heavy-read semaphore.
- `content_type=all` can be expensive because it fans out across modalities and then globally sorts.
- App/window/frame filters avoid audio fan-out for `all`, reducing work.
- `max_content_length` is useful for agents and MCP to keep outputs small.
- `include_frames=true` is expensive because it extracts/embeds images and disables caching.
- `/search/keyword?group=true` is intentionally lighter than full `/search` because it skips large text blobs.

## Common Gotchas

- `OCR` does not always mean OCR. It is the frame/screen result type. Check `text_source`.
- `UI` is deprecated and mostly represents accessibility text traversal. Current screen text is frame-backed.
- `Input` is user actions. It is not the same as accessibility text.
- `browser_url` and `focused` force frame/OCR search.
- `on_screen` only makes sense for accessibility-bearing searches.
- `content_type=all` pagination is global after merge, not per-source.
- Search filters out screenpipe's own app rows after DB search, so `pagination.total` can be higher than returned visible rows in edge cases.
- Live meeting transcript search returns synthetic negative chunk ids.
- `/search/keyword` returns a bare array, unlike `/search`.
- The query parameter for keyword search is `query`, not `q`.
- Adding new query params requires updating route parsing, DB dispatch, count logic, cache key, CLI args if applicable, MCP mappings if exposed, and tests.

## Best Files to Read First

- `crates/screenpipe-engine/src/routes/search.rs`: route parser, response conversion, cache, PII redaction, keyword handler.
- `crates/screenpipe-engine/src/routes/content.rs`: public `ContentItem` response schema.
- `crates/screenpipe-db/src/types.rs`: `ContentType`, `SearchResult`, raw/result structs.
- `crates/screenpipe-db/src/db.rs`: `DatabaseManager::search`, source-specific SQL, counts, keyword search, grouping.
- `crates/screenpipe-engine/src/server.rs`: route registration and cache type.
- `crates/screenpipe-engine/src/cli/search.rs`: CLI mirror of `/search`.
- `packages/screenpipe-mcp/src/index.ts`: model-facing search tools and query parameter mapping.
- `crates/screenpipe-core/src/pipes/permissions.rs`: pipe permission model for `GET /search`.
- `crates/screenpipe-core/src/agents/bash_env.rs`: privacy-filter curl rewrite behavior.

## Mental Model

`/search` is not one index. It is a coordinator over multiple capture-backed stores:

1. Build filters from HTTP params.
2. Dispatch to the relevant SQLite tables and FTS indexes.
3. Merge and sort rows into one timeline-like result stream.
4. Convert internal rows into public `ContentItem` variants.
5. Apply product-level cleanup: remove screenpipe self-results, dedupe old UI/frame duplicates, redact PII, optionally attach frames, cache.

When debugging search, first identify the missing modality (`frames`, `audio_transcriptions`, `meeting_transcript_segments`, `ui_events`, `memories`), then inspect the specific DB method for that modality and verify whether route-level post-processing filtered or transformed the row.
