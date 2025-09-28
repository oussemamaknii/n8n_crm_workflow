-- TalentAI Contact Management Database Schema

-- Create extension for case-insensitive text (citext)
CREATE EXTENSION IF NOT EXISTS citext;

-- Create extension for UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Contacts table with proper normalization and indexing
CREATE TABLE IF NOT EXISTS contacts (
    id                  BIGSERIAL PRIMARY KEY,
    uuid                UUID DEFAULT uuid_generate_v4() UNIQUE NOT NULL,
    crm_id              VARCHAR(64) UNIQUE NOT NULL,
    first_name          TEXT,
    last_name           TEXT,
    full_name           TEXT GENERATED ALWAYS AS (
                          CASE 
                            WHEN first_name IS NOT NULL AND last_name IS NOT NULL 
                            THEN UPPER(TRIM(first_name || ' ' || last_name))
                            WHEN first_name IS NOT NULL 
                            THEN UPPER(TRIM(first_name))
                            WHEN last_name IS NOT NULL 
                            THEN UPPER(TRIM(last_name))
                            ELSE NULL
                          END
                        ) STORED,
    email               CITEXT,
    phone_e164          VARCHAR(20),
    phone_raw           TEXT,
    company             TEXT,
    job_title           TEXT,
    tags                TEXT[],
    raw_payload         JSONB,
    source              VARCHAR(50) DEFAULT 'n8n_workflow',
    status              VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'deleted')),
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW(),
    processed_at        TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_contacts_crm_id ON contacts(crm_id);
CREATE INDEX IF NOT EXISTS idx_contacts_email ON contacts(email) WHERE email IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_contacts_phone ON contacts(phone_e164) WHERE phone_e164 IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_contacts_created_at ON contacts(created_at);
CREATE INDEX IF NOT EXISTS idx_contacts_company ON contacts(company) WHERE company IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_contacts_status ON contacts(status);

-- GIN index for JSONB raw_payload
CREATE INDEX IF NOT EXISTS idx_contacts_raw_payload ON contacts USING GIN(raw_payload);

-- GIN index for tags array
CREATE INDEX IF NOT EXISTS idx_contacts_tags ON contacts USING GIN(tags);

-- Composite index for common queries
CREATE INDEX IF NOT EXISTS idx_contacts_source_status_created ON contacts(source, status, created_at);

-- Audit/Log table for tracking processing results
CREATE TABLE IF NOT EXISTS contact_processing_log (
    id                  BIGSERIAL PRIMARY KEY,
    contact_id          BIGINT REFERENCES contacts(id),
    crm_id              VARCHAR(64),
    operation           VARCHAR(50) NOT NULL, -- 'insert', 'update', 'duplicate', 'error'
    status              VARCHAR(20) NOT NULL, -- 'success', 'warning', 'error'
    message             TEXT,
    execution_time_ms   INTEGER,
    raw_input           JSONB,
    workflow_execution  VARCHAR(100),
    created_at          TIMESTAMPTZ DEFAULT NOW()
);

-- Index for log queries
CREATE INDEX IF NOT EXISTS idx_log_contact_id ON contact_processing_log(contact_id);
CREATE INDEX IF NOT EXISTS idx_log_crm_id ON contact_processing_log(crm_id);
CREATE INDEX IF NOT EXISTS idx_log_status_created ON contact_processing_log(status, created_at);
CREATE INDEX IF NOT EXISTS idx_log_operation ON contact_processing_log(operation);

-- Error tracking table
CREATE TABLE IF NOT EXISTS processing_errors (
    id                  BIGSERIAL PRIMARY KEY,
    error_code          VARCHAR(50),
    error_message       TEXT NOT NULL,
    error_details       JSONB,
    input_data          JSONB,
    workflow_step       VARCHAR(100),
    retry_count         INTEGER DEFAULT 0,
    resolved            BOOLEAN DEFAULT FALSE,
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    resolved_at         TIMESTAMPTZ
);

-- Index for error tracking
CREATE INDEX IF NOT EXISTS idx_errors_resolved_created ON processing_errors(resolved, created_at);
CREATE INDEX IF NOT EXISTS idx_errors_code ON processing_errors(error_code);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger to auto-update updated_at
CREATE TRIGGER update_contacts_updated_at 
    BEFORE UPDATE ON contacts 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Create a view for easy contact reporting
CREATE OR REPLACE VIEW contact_summary AS
SELECT 
    c.id,
    c.uuid,
    c.crm_id,
    c.full_name,
    c.email,
    c.phone_e164,
    c.company,
    c.job_title,
    c.status,
    c.source,
    c.created_at,
    c.updated_at,
    COALESCE(l.last_processed, c.processed_at) as last_processed
FROM contacts c
LEFT JOIN (
    SELECT 
        contact_id,
        MAX(created_at) as last_processed
    FROM contact_processing_log 
    WHERE status = 'success'
    GROUP BY contact_id
) l ON c.id = l.contact_id
WHERE c.status = 'active';

-- Grant permissions to n8n user
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO n8n_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO n8n_user;
GRANT USAGE ON SCHEMA public TO n8n_user;

COMMIT;
