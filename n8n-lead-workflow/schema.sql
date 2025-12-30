-- ================================================
-- Lead Management Database Schema
-- For use with n8n workflow and Cloudflare Worker
-- ================================================

-- Extension for UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ================================================
-- Table: clients
-- Stores business client information
-- ================================================
CREATE TABLE IF NOT EXISTS clients (
    client_id VARCHAR(50) PRIMARY KEY,
    business_name VARCHAR(255) NOT NULL,
    owner_phone VARCHAR(50) NOT NULL,
    owner_email VARCHAR(255) NOT NULL,
    notify_sms BOOLEAN DEFAULT true,
    notify_email BOOLEAN DEFAULT true,
    auto_reply_enabled BOOLEAN DEFAULT false,
    auto_reply_sms TEXT,
    auto_reply_email_subject VARCHAR(255),
    auto_reply_email_body TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Index for fast lookups
CREATE INDEX idx_clients_client_id ON clients(client_id);

-- ================================================
-- Table: leads
-- Stores all incoming leads with metadata
-- ================================================
CREATE TABLE IF NOT EXISTS leads (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    client_id VARCHAR(50) NOT NULL REFERENCES clients(client_id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    phone VARCHAR(50) NOT NULL,
    email VARCHAR(255),
    message TEXT NOT NULL,
    service VARCHAR(255),
    source VARCHAR(100),
    utm TEXT,
    ip VARCHAR(45),
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    processed_at TIMESTAMP WITH TIME ZONE,
    status VARCHAR(50) DEFAULT 'new',
    raw JSONB,
    
    -- Constraints
    CONSTRAINT leads_name_min_length CHECK (LENGTH(TRIM(name)) >= 2),
    CONSTRAINT leads_phone_min_length CHECK (LENGTH(TRIM(phone)) >= 7)
);

-- Indexes for performance
CREATE INDEX idx_leads_client_id ON leads(client_id);
CREATE INDEX idx_leads_created_at ON leads(created_at DESC);
CREATE INDEX idx_leads_status ON leads(status);
CREATE INDEX idx_leads_source ON leads(source);
CREATE INDEX idx_leads_raw_gin ON leads USING gin(raw jsonb_path_ops);

-- ================================================
-- Seed Data: Insert Reliant Clean & Repair
-- ================================================
INSERT INTO clients (
    client_id,
    business_name,
    owner_phone,
    owner_email,
    notify_sms,
    notify_email,
    auto_reply_enabled,
    auto_reply_sms,
    auto_reply_email_subject,
    auto_reply_email_body
) VALUES (
    'reliant',
    'Reliant Clean & Repair',
    '+15551234567', -- CHANGE THIS to real phone
    'owner@reliantcleanandrepair.com', -- CHANGE THIS to real email
    true,
    true,
    true,
    'Thank you for contacting Reliant Clean & Repair! We received your request and will respond within 24 hours. Call us at (555) 123-4567 if you need immediate assistance.',
    'Thank You for Contacting Reliant Clean & Repair',
    'Hi {{name}},

Thank you for reaching out to Reliant Clean & Repair!

We received your inquiry about: {{service}}

Our team will review your request and get back to you within 24 hours with a detailed quote.

In the meantime, if you have any urgent questions, feel free to call us at (555) 123-4567.

Best regards,
Reliant Clean & Repair Team

---
This is an automated response. Please do not reply to this email.'
) ON CONFLICT (client_id) DO UPDATE SET
    owner_phone = EXCLUDED.owner_phone,
    owner_email = EXCLUDED.owner_email,
    updated_at = CURRENT_TIMESTAMP;

-- ================================================
-- Views for Analytics (Optional)
-- ================================================

-- View: Recent leads by client
CREATE OR REPLACE VIEW v_recent_leads AS
SELECT 
    l.id,
    l.client_id,
    c.business_name,
    l.name,
    l.phone,
    l.email,
    l.service,
    l.source,
    l.status,
    l.created_at
FROM leads l
JOIN clients c ON l.client_id = c.client_id
ORDER BY l.created_at DESC;

-- View: Lead counts by source
CREATE OR REPLACE VIEW v_leads_by_source AS
SELECT 
    client_id,
    source,
    COUNT(*) as lead_count,
    DATE(created_at) as date
FROM leads
GROUP BY client_id, source, DATE(created_at)
ORDER BY date DESC, lead_count DESC;

-- ================================================
-- Functions (Optional)
-- ================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for clients table
CREATE TRIGGER update_clients_updated_at
    BEFORE UPDATE ON clients
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ================================================
-- Cleanup Function (Optional)
-- Delete leads older than 1 year
-- ================================================
CREATE OR REPLACE FUNCTION cleanup_old_leads()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM leads
    WHERE created_at < NOW() - INTERVAL '1 year'
    AND status IN ('processed', 'spam');
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- ================================================
-- Grant Permissions (adjust as needed)
-- ================================================
-- If using the n8n_user from docker setup:
GRANT SELECT, INSERT, UPDATE ON clients TO n8n_user;
GRANT SELECT, INSERT, UPDATE ON leads TO n8n_user;
GRANT SELECT ON v_recent_leads TO n8n_user;
GRANT SELECT ON v_leads_by_source TO n8n_user;

-- ================================================
-- Verification Queries
-- ================================================
-- Check if tables were created:
-- SELECT table_name FROM information_schema.tables WHERE table_schema = 'public';

-- Check seed data:
-- SELECT * FROM clients WHERE client_id = 'reliant';

-- Test lead insert:
-- INSERT INTO leads (client_id, name, phone, email, message, source, raw)
-- VALUES ('reliant', 'Test User', '5551234567', 'test@example.com', 'Test message', 'website', '{"test": true}');

-- View recent leads:
-- SELECT * FROM v_recent_leads LIMIT 10;
