CREATE TABLE IF NOT EXISTS sync_batches (
    org_id TEXT NOT NULL,
    batch_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    device_id TEXT NOT NULL,
    schema_version INTEGER NOT NULL,
    status TEXT NOT NULL,
    sha256 TEXT NOT NULL,
    byte_count BIGINT NOT NULL,
    atom_count BIGINT NOT NULL,
    input_signal_count BIGINT NOT NULL,
    dropped_count BIGINT NOT NULL,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ NOT NULL,
    cursor_before JSONB NOT NULL,
    cursor_after JSONB NOT NULL,
    object_key TEXT,
    error TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at TIMESTAMPTZ,
    PRIMARY KEY (org_id, batch_id)
);

CREATE TABLE IF NOT EXISTS content_atoms (
    org_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    device_id TEXT NOT NULL,
    atom_id TEXT NOT NULL,
    batch_id TEXT NOT NULL,
    frame_id BIGINT,
    timestamp TIMESTAMPTZ NOT NULL,
    app_name TEXT NOT NULL,
    window_name TEXT NOT NULL,
    browser_url TEXT,
    text TEXT NOT NULL,
    role TEXT NOT NULL,
    bounds JSONB,
    score DOUBLE PRECISION NOT NULL,
    reasons JSONB NOT NULL,
    first_seen TIMESTAMPTZ NOT NULL,
    last_seen TIMESTAMPTZ NOT NULL,
    seen_count BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (org_id, atom_id)
);

CREATE INDEX IF NOT EXISTS idx_content_atoms_user_day
ON content_atoms (org_id, user_id, timestamp);

CREATE TABLE IF NOT EXISTS input_signals (
    org_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    device_id TEXT NOT NULL,
    signal_id TEXT NOT NULL,
    batch_id TEXT NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL,
    frame_id BIGINT,
    event_type TEXT NOT NULL,
    app_name TEXT,
    window_title TEXT,
    browser_url TEXT,
    text_content TEXT,
    element_role TEXT,
    element_name TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (org_id, signal_id)
);

CREATE INDEX IF NOT EXISTS idx_input_signals_user_day
ON input_signals (org_id, user_id, timestamp);

CREATE TABLE IF NOT EXISTS ingest_cursors (
    org_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    device_id TEXT NOT NULL,
    cursor_state JSONB NOT NULL,
    batch_id TEXT NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (org_id, user_id, device_id)
);
