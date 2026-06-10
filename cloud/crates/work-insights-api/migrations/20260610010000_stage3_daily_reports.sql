CREATE TABLE IF NOT EXISTS timeline_segments (
    org_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    report_date DATE NOT NULL,
    segment_id TEXT NOT NULL,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ NOT NULL,
    app_names JSONB NOT NULL,
    window_names JSONB NOT NULL,
    browser_urls JSONB NOT NULL,
    atom_ids JSONB NOT NULL,
    input_hash TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (org_id, segment_id)
);

CREATE INDEX IF NOT EXISTS idx_timeline_segments_user_day
ON timeline_segments (org_id, user_id, report_date, start_time);

CREATE TABLE IF NOT EXISTS agent_runs (
    org_id TEXT NOT NULL,
    run_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    report_date DATE NOT NULL,
    run_type TEXT NOT NULL,
    model TEXT NOT NULL,
    prompt_version TEXT NOT NULL,
    input_hash TEXT NOT NULL,
    status TEXT NOT NULL,
    error TEXT,
    request_json JSONB NOT NULL,
    response_json JSONB,
    usage_json JSONB,
    started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at TIMESTAMPTZ,
    duration_ms BIGINT,
    PRIMARY KEY (org_id, run_id)
);

CREATE INDEX IF NOT EXISTS idx_agent_runs_user_day
ON agent_runs (org_id, user_id, report_date, started_at);

CREATE TABLE IF NOT EXISTS segment_reports (
    org_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    report_date DATE NOT NULL,
    segment_id TEXT NOT NULL,
    prompt_version TEXT NOT NULL,
    model TEXT NOT NULL,
    input_hash TEXT NOT NULL,
    status TEXT NOT NULL,
    report_json JSONB,
    error TEXT,
    agent_run_id TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (org_id, segment_id, prompt_version, model, input_hash)
);

CREATE INDEX IF NOT EXISTS idx_segment_reports_user_day
ON segment_reports (org_id, user_id, report_date);

CREATE TABLE IF NOT EXISTS user_reports (
    org_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    report_date DATE NOT NULL,
    status TEXT NOT NULL,
    report_json JSONB NOT NULL,
    markdown TEXT NOT NULL,
    evidence_refs JSONB NOT NULL,
    model TEXT NOT NULL,
    prompt_version TEXT NOT NULL,
    input_hash TEXT NOT NULL,
    generated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (org_id, user_id, report_date)
);
