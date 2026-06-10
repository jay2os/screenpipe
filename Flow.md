# Capture Flow

This document is a handoff map for agents working on the local capture pipeline. It focuses on how screen, accessibility, OCR, browser context, UI events, audio, transcription, chunking, and SQLite storage fit together.

## High-Level Shape

The current screen pipeline is event-driven. The old continuous video capture path was removed from `crates/screenpipe-engine/src/core.rs`; the active path is `crates/screenpipe-engine/src/event_driven_capture.rs`.

Main crates:

- `crates/screenpipe-engine`: orchestration, capture loops, server routes, managers.
- `crates/screenpipe-screen`: monitor/window screenshot capture, OCR engines, browser URL helpers.
- `crates/screenpipe-capture`: paired screenshot + accessibility + OCR persistence logic.
- `crates/screenpipe-a11y`: OS accessibility/input event capture and tree walking.
- `crates/screenpipe-audio`: device capture, audio segmentation, STT, live meeting transcription, reconciliation.
- `crates/screenpipe-db`: SQLite schema, migrations, write queue, query APIs.
- `packages/browser-extension`: optional browser WebSocket bridge for evaluating JS/getting cookies in browser tabs.

Canonical local DB is `~/.screenpipe/db.sqlite`. The DB uses WAL files beside it. Most writes go through `screenpipe-db` write queue paths to reduce contention.

## Screen / Accessibility / OCR Flow

### Manager Startup

`VisionManager` in `crates/screenpipe-engine/src/vision_manager/manager.rs` owns per-monitor capture tasks.

Important wiring:

- It creates one broadcast trigger channel shared by all monitor capture loops and the UI recorder.
- It creates one frame-linker actor shared by the UI recorder and capture loops.
- It starts one event-driven capture loop per allowed monitor.
- It applies monitor filters, power profile, focus-aware state, high-FPS override, DRM pause, work schedule pause, and hot-frame cache integration.

### UI / A11y Event Capture

`start_ui_recording` in `crates/screenpipe-engine/src/ui_recorder.rs` starts `screenpipe_a11y::UiRecorder`.

The UI recorder captures:

- App switches.
- Window focus changes.
- Clicks.
- Scrolls.
- Text bursts.
- Optional raw keys.
- Clipboard operations.
- Accessibility element context for input events.

It converts OS events into `InsertUiEvent` rows and flushes them in batches to `ui_events`.

Privacy gates are separate from trigger gates:

- `record_keyboard_events=false` can prevent key/text rows from being stored.
- `record_clipboard_events=false` can prevent clipboard rows/content from being stored.
- Key/clipboard activity can still emit trigger-only capture messages if configured to wake capture.

Trigger correlation:

- For events that should both be persisted and trigger a capture, the UI recorder mints a correlation id.
- The trigger is broadcast to monitor loops as `CaptureTriggerMsg`.
- After the event batch flushes, the recorder sends `EventPersisted { correlation_id, row_id }` to the frame-linker actor.
- When a frame is captured, the capture loop sends `FrameCaptured { frame_id, correlation_ids }`.
- The frame-linker actor updates `ui_events.frame_id`.

Scroll is debounced specially: many scroll rows are reduced into one `ScrollStop` trigger linked to the last scroll row in the burst.

### Event-Driven Monitor Capture

`event_driven_capture_loop` in `crates/screenpipe-engine/src/event_driven_capture.rs` runs per monitor.

Primary trigger types:

- `AppSwitch`
- `WindowFocus`
- `Click`
- `TypingPause`
- `ScrollStop`
- `KeyPress`
- `Clipboard`
- `VisualChange`
- `Idle`
- `Manual`

The loop:

- Captures once at startup unless screen lock, DRM, or schedule pause blocks it.
- Blocks on the trigger channel, then drains all pending triggers into one reduced capture.
- Accumulates all correlation ids from the drained trigger burst so many UI events can point at one resulting frame.
- Periodically performs visual-change checks by screenshot diff.
- Performs idle fallback capture.
- Skips or slows capture for cold/warm non-focused monitors.
- Releases OS capture streams when paused, locked, DRM-paused, schedule-paused, or cold.
- Applies debounce, but workflow checkpoint triggers can bypass debounce.
- On dedup/debounce, links events to the previous frame when that is semantically valid.

### Paired Capture

Actual capture persistence is centralized in `crates/screenpipe-capture/src/paired_capture.rs`.

`paired_capture` receives:

- Screenshot image.
- Optional accessibility tree snapshot.
- App/window/browser metadata.
- Document path when available.
- Capture trigger.
- PII removal flag.
- OCR languages.
- Optional `elements_ref_frame_id` for element dedup.

It then:

1. Writes the JPEG snapshot to disk unless screenshots are disabled by power profile.
2. Uses accessibility tree text if it is good enough.
3. Runs OCR if accessibility has no text, the app prefers OCR, or accessibility looks "thin".
4. Sanitizes text if PII removal is enabled.
5. Inserts a `frames` row via `insert_snapshot_frame_with_ocr`.
6. Optionally inserts `ocr_text` in the same write operation.
7. Defers structured `elements` insertion for OCR/accessibility node data.

Text source values:

- `accessibility`: tree text and nodes are the primary source.
- `ocr`: OCR fallback produced the text.
- `hybrid`: accessibility exists but is thin, so OCR is also stored to capture real visual content.

Thin accessibility cases include canvas/document apps and meeting/video apps where the a11y tree often exposes only UI chrome.

### OCR Engines

OCR implementation lives in `crates/screenpipe-screen`:

- macOS: `perform_ocr_apple` in `src/apple.rs`.
- Windows: `perform_ocr_windows` in `src/microsoft.rs`.
- Linux/other: `perform_ocr_tesseract` in `src/tesseract.rs`.

OCR output includes flat text and JSON with per-box positions. The JSON is later converted into `elements` rows for overlay/search/highlight use.

### Browser URL Context

Browser URL metadata is stored directly on screen/UI rows:

- `frames.browser_url`
- `ui_events.browser_url`

URL detection is platform-specific in `crates/screenpipe-screen/src/browser_utils/` via `BrowserUrlDetector`.

The browser extension is separate:

- Extension worker: `packages/browser-extension/src/worker.ts`.
- Server adapter: `crates/screenpipe-engine/src/routes/browser.rs`.

The extension maintains a WebSocket to `/browser/ws`, handles heartbeat, and runs requested tab JS or cookie requests. It is not the main source of `frames` capture, but it can enrich browser-based workflows.

## Audio / Transcription Flow

### Manager Startup

`AudioManager` in `crates/screenpipe-audio/src/audio_manager/manager.rs` owns device capture and transcription consumers.

At start:

- Starts the transcription receiver handler.
- Starts the audio receiver handler.
- Starts live meeting streaming loop when configured.
- Starts the device monitor.
- In batch mode, starts reconciliation sweeps for old/untranscribed chunks.

Audio channels:

- `recording_sender` / `recording_receiver`: raw 30s-ish audio chunks from device recorders to processing.
- `transcription_sender` / `transcription_receiver`: STT results from processing to DB insertion.

### Device Recording

`run_record_and_transcribe` in `crates/screenpipe-audio/src/core/run_record_and_transcribe.rs` captures each device stream.

Important behavior:

- Recording uses fixed segments, usually 30 seconds.
- Each segment keeps a 2-second overlap tail.
- Input/output audio is normalized into mono recorder output for downstream handling.
- The source buffer repairs packet-drop gaps by inserting silence.
- While live meeting streaming is active, audio frames are also tapped into `MeetingAudioTap`.
- Segment timestamp is set when audio entered the recording channel, not when it is processed.

The recorder sends `AudioInput` into the processing channel with:

- PCM samples.
- Device metadata.
- Sample rate/channel metadata.
- Original capture timestamp.

### Early Disk and DB Persistence

The audio receiver handler in `AudioManager` always persists audio to disk before deferral or STT.

After writing the audio file, it inserts an `audio_chunks` row immediately:

- `audio_chunks.file_path` points to the persisted audio file.
- `audio_chunks.timestamp` is the original capture time.
- `audio_chunks.transcription_status` starts as `pending`.

This is intentional. Even if transcription is deferred, crashes, or is disabled temporarily, retranscription/reconciliation can find the audio later.

### Realtime vs Batch Mode

Realtime mode:

- Every persisted chunk is immediately passed to `process_audio_input`.
- VAD/segmentation/STT runs as soon as the chunk arrives.
- Results go through `handle_new_transcript` into DB.

Batch mode:

- During detected audio sessions or meetings, chunks are written to disk and DB but transcription is deferred.
- When the session ends, reconciliation transcribes accumulated untranscribed chunks.
- A background reconciliation sweep also runs periodically for stale pending chunks.

### VAD, Segmentation, Speaker Embeddings, STT

`process_audio_input` in `crates/screenpipe-audio/src/transcription/stt.rs`:

1. Resamples to `SAMPLE_RATE = 16000`.
2. Runs `prepare_segments` using VAD, optional segmentation model, embedding manager, and optional music filtering.
3. Skips transcription if speech ratio is too low.
4. Uses a pre-written path when available, otherwise writes the audio file.
5. Runs STT per speech segment.
6. Emits `TranscriptionResult` with transcript, path, timestamp, segment offsets, speaker embedding, and diarization data.

STT engines are selected through `TranscriptionEngine` / `TranscriptionSession`:

- Disabled.
- Deepgram, with near-silence skip and Whisper fallback.
- OpenAI-compatible.
- Whisper.
- Qwen3-ASR / Parakeet via alternate STT where compiled.

### Transcript DB Insert

`handle_new_transcript` in `crates/screenpipe-audio/src/transcription/handle_new_transcript.rs` receives `TranscriptionResult`.

It:

- Records pipeline metrics.
- Drops empty transcripts.
- Deduplicates overlap per device using the previous transcript.
- Calls `process_transcription_result`.
- Inserts/updates DB audio rows.
- Calls optional hot-frame-cache callback after successful insert.

The write queue path inserts:

- `audio_transcriptions` rows tied to an `audio_chunk_id`.
- Updates the corresponding `audio_chunks.transcription_status` to `transcribed` in the same transaction.

### Reconciliation

`crates/screenpipe-audio/src/audio_manager/reconciliation.rs` handles old or deferred `audio_chunks`.

It:

- Prevents concurrent reconciliation runs.
- Retries pending transcription files from disk.
- Finds candidate chunks with no transcription row/status still pending.
- Groups consecutive chunks by device.
- Concatenates chunks up to an engine-specific max duration.
- Runs STT as a larger batch for more context.
- Writes results back to the primary chunk and marks secondary chunks appropriately.

Default max batch durations are engine-specific. For example, Deepgram is capped below its service limits; Parakeet is kept short; Whisper/Qwen-style engines can use longer batches.

## Live Meeting Transcription

Live meeting transcription is separate from background audio transcription.

Important tables:

- `meetings`
- `meeting_transcript_segments`
- `audio_chunks`
- `audio_transcriptions`

When live meeting streaming is active:

- Recorder audio is tapped into the live provider/session.
- Background STT can be suppressed for those chunks.
- Live final transcript segments are stored in `meeting_transcript_segments`.
- DB helpers can mark covered audio chunks as `transcribed`.
- Finished live transcript segments can later be mirrored into `audio_transcriptions` so global search/timeline remains consistent.

Relevant files:

- `crates/screenpipe-audio/src/meeting_streaming/controller.rs`
- `crates/screenpipe-audio/src/meeting_streaming/deepgram_live.rs`
- `crates/screenpipe-audio/src/meeting_streaming/selected_engine.rs`
- `crates/screenpipe-db/src/db.rs` meeting methods around `insert_meeting_transcript_segment`, `mark_chunks_covered_by_live`, and `mirror_live_meeting_to_audio_transcriptions`.

## SQLite Storage Map

### Core Screen Tables

`frames`

- One row per persisted screen/accessibility snapshot.
- Current event-driven captures use `video_chunk_id = NULL`, `offset_index = 0`, and `snapshot_path` for JPEG snapshots.
- Key columns: `timestamp`, `browser_url`, `app_name`, `window_name`, `focused`, `device_name`, `snapshot_path`, `capture_trigger`, `accessibility_text`, `text_source`, `accessibility_tree_json`, `content_hash`, `simhash`, `full_text`, `elements_ref_frame_id`, `document_path`.
- `full_text` is the indexed/search text used by `frames_fts`.

`ocr_text`

- OCR text tied to a `frame_id`.
- Stores `text`, `text_json`, `ocr_engine`, `text_length`, and duplicated app/window/focus metadata in newer code.
- Used for legacy OCR queries and overlay/highlight data.

`elements`

- Unified structured nodes for OCR and accessibility.
- `source` is `ocr` or `accessibility`.
- Stores role, text, hierarchy, normalized bounds, confidence, and sort order.
- `elements_ref_frame_id` on `frames` can point a frame at another frame's elements when content hash did not change.

`video_chunks`

- Legacy/compacted video storage.
- Event-driven snapshot captures primarily use `frames.snapshot_path`; `video_chunks` still exists for video/export/older paths.

### UI / A11y Event Tables

`ui_events`

- Discrete input/app/window events.
- Key columns: `timestamp`, `session_id`, `relative_ms`, `event_type`, mouse/key fields, `text_content`, app/window/browser metadata, accessibility element metadata, and `frame_id`.
- `frame_id` is nullable because not every event produces or links to a frame.

`ui_events_fts`

- FTS index over event text/app/window/element fields.

Accessibility text table note:

- Older migrations had a separate accessibility table.
- Current capture consolidates accessibility text into `frames.accessibility_text` / `frames.full_text`.
- Structured accessibility nodes go into `elements`.

### Audio Tables

`audio_chunks`

- One row per persisted audio segment file.
- Key columns: `file_path`, `timestamp`, `transcription_status`, `transcription_attempts`, `last_transcription_attempt_at`, `transcription_failure_reason`.
- Exists before transcription in batch/deferred paths.

`audio_transcriptions`

- One row per transcript segment tied to `audio_chunk_id`.
- Key columns: `transcription`, `offset_index`, `timestamp`, `transcription_engine`, `device`, `is_input_device`, `speaker_id`, `start_time`, `end_time`, `text_length`.
- Unique on `(audio_chunk_id, transcription)`.

`audio_transcriptions_fts`

- FTS over audio transcription text and related fields.

Speaker/diarization support:

- Speaker ids and diarization segment tables are handled by migrations in `crates/screenpipe-db/src/migrations`, especially recent audio diarization and speaker-id migrations.

### Meeting Tables

`meetings`

- Meeting intervals and metadata.
- Recent migrations enforce at most one open meeting and add `end_reason`.

`meeting_transcript_segments`

- Live meeting transcript finals.
- Meeting-owned data, separate from `audio_transcriptions`.
- Can be mirrored/backfilled into audio transcription paths after the meeting.

### Tags and Search

Tag tables:

- `tags`
- `vision_tags`
- `audio_tags`

FTS tables:

- `frames_fts`: external-content FTS over `frames.full_text`, app/window/browser URL.
- `ocr_text_fts`: external-content FTS over OCR rows.
- `audio_transcriptions_fts`: external-content FTS over transcript rows.
- `ui_events_fts`: FTS over UI event text/context.
- `elements_fts`: FTS over structured OCR/a11y elements.

## Chunking and Dedup Rules

Screen:

- Event-driven captures are per monitor and usually produce individual JPEG snapshots, not continuous video chunks.
- Consecutive trigger bursts are reduced into one capture, but all correlation ids can link to the one frame.
- `content_hash`/`simhash` come from accessibility/OCR text and are used to skip duplicate DB writes.
- If content dedup skips a capture, triggering events can link to the previous frame.
- `elements_ref_frame_id` avoids reinserting duplicate OCR/a11y element rows when content hash is unchanged.
- Idle captures are phased across monitors to avoid simultaneous multi-monitor spikes.

Audio:

- Recorder segments are 30 seconds with a 2-second overlap.
- The overlap is cleaned in transcript handling to avoid repeated words.
- Audio files and `audio_chunks` rows are persisted before STT.
- VAD/segmentation can produce zero, one, or multiple speech segments from one audio chunk.
- One `audio_chunk` can have multiple `audio_transcriptions` rows when multiple speech segments are produced.
- Batch reconciliation can group multiple consecutive `audio_chunks` into one larger transcription request.
- Live meeting chunks can be marked covered by live segments to avoid duplicate background STT.

UI events:

- UI events are batch-inserted.
- Many UI events can link to one frame.
- Some UI events intentionally remain with `frame_id = NULL` when capture is disabled, paused, dropped, unlinked, or not meaningful.

## Important Entry Points for Future Agents

Start with these files for capture-flow work:

- `crates/screenpipe-engine/src/vision_manager/manager.rs`: screen manager wiring.
- `crates/screenpipe-engine/src/event_driven_capture.rs`: per-monitor event-driven state machine.
- `crates/screenpipe-engine/src/ui_recorder.rs`: a11y/input event capture and trigger generation.
- `crates/screenpipe-engine/src/frame_linker_actor.rs`: UI event to frame correlation.
- `crates/screenpipe-capture/src/paired_capture.rs`: screenshot + a11y + OCR DB insert.
- `crates/screenpipe-screen/src/monitor.rs`: monitor screenshot capture.
- `crates/screenpipe-screen/src/browser_utils/`: active browser URL detection.
- `crates/screenpipe-audio/src/audio_manager/manager.rs`: audio orchestration.
- `crates/screenpipe-audio/src/core/run_record_and_transcribe.rs`: device segment recorder.
- `crates/screenpipe-audio/src/transcription/stt.rs`: VAD/segmentation/STT.
- `crates/screenpipe-audio/src/transcription/handle_new_transcript.rs`: transcript dedup and DB handoff.
- `crates/screenpipe-audio/src/audio_manager/reconciliation.rs`: batch/deferred transcription.
- `crates/screenpipe-db/src/write_queue.rs`: serialized write operations and insert SQL.
- `crates/screenpipe-db/src/db.rs`: query APIs, search, meetings, reconciliation helpers.
- `crates/screenpipe-db/src/migrations/`: authoritative schema evolution.
- `packages/browser-extension/src/worker.ts`: browser bridge client.
- `crates/screenpipe-engine/src/routes/browser.rs`: browser bridge server route.

## Mental Model

Think of capture as four independent but time-correlated streams:

1. `frames`: point-in-time view of what was on screen, with accessibility/OCR text.
2. `ui_events`: what the user did, optionally linked to a nearby/caused frame.
3. `audio_chunks` plus `audio_transcriptions`: what was heard/said, with durable audio files and delayed transcription support.
4. `meeting_transcript_segments`: live meeting transcript finals, later reconciled or mirrored with background audio data.

The system does not require every event to have every modality. Correct behavior often means partial data:

- A UI event without `frame_id` can be valid.
- An `audio_chunk` without `audio_transcriptions` can be valid while pending/deferred.
- A frame can have accessibility text without OCR text.
- A frame can have OCR text because accessibility was absent or thin.
- A live meeting segment can exist without a background audio transcription row yet.

When debugging, first identify which stream is missing or delayed, then follow the specific producer and DB write path above.
