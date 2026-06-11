ALTER TABLE agent_runs
ADD COLUMN IF NOT EXISTS response_text TEXT;
