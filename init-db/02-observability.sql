-- Observability additions: run-level logging and stronger relations

-- 1) Run-level table capturing one row per n8n execution
CREATE TABLE IF NOT EXISTS ingestion_runs (
    id                  BIGSERIAL PRIMARY KEY,
    execution_id        TEXT NOT NULL,
    workflow_id         TEXT NOT NULL,
    started_at          TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    finished_at         TIMESTAMPTZ,
    status              VARCHAR(20) NOT NULL DEFAULT 'started' CHECK (status IN ('started','success','warning','error')),
    contacts_received   INT DEFAULT 0,
    contacts_inserted   INT DEFAULT 0,
    duplicates          INT DEFAULT 0,
    email_sent          INT DEFAULT 0,
    error_count         INT DEFAULT 0,
    notes               TEXT
);

CREATE INDEX IF NOT EXISTS idx_runs_started_desc ON ingestion_runs (started_at DESC);
CREATE INDEX IF NOT EXISTS idx_runs_status_started ON ingestion_runs (status, started_at);

-- 2) Strengthen contact_processing_log with run linkage and richer metadata
ALTER TABLE contact_processing_log
    ADD COLUMN IF NOT EXISTS run_id BIGINT REFERENCES ingestion_runs(id),
    ADD COLUMN IF NOT EXISTS node_name TEXT,
    ADD COLUMN IF NOT EXISTS event_type VARCHAR(50),
    ADD COLUMN IF NOT EXISTS attempt INT DEFAULT 0,
    ADD COLUMN IF NOT EXISTS duration_ms INT;

CREATE INDEX IF NOT EXISTS idx_log_run_id ON contact_processing_log(run_id);
CREATE INDEX IF NOT EXISTS idx_log_event_created ON contact_processing_log(event_type, created_at DESC);

-- 3) Strengthen processing_errors with run/contact linkage and execution id
ALTER TABLE processing_errors
    ADD COLUMN IF NOT EXISTS run_id BIGINT REFERENCES ingestion_runs(id),
    ADD COLUMN IF NOT EXISTS contact_id BIGINT REFERENCES contacts(id),
    ADD COLUMN IF NOT EXISTS execution_id TEXT;

CREATE INDEX IF NOT EXISTS idx_errors_run_id ON processing_errors(run_id);
CREATE INDEX IF NOT EXISTS idx_errors_execution_id ON processing_errors(execution_id);

COMMIT;


