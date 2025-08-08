-- n8n Database Initialization Script
-- This script sets up the initial database structure and configuration for n8n

-- Enable required PostgreSQL extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Create database user if not exists (for local development)
-- Note: In Render, the user is created automatically via render.yaml
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'n8n_user') THEN
        CREATE ROLE n8n_user WITH LOGIN PASSWORD 'temp_password';
    END IF;
END
$$;

-- Grant necessary permissions to n8n_user
GRANT CONNECT ON DATABASE n8n_db TO n8n_user;
GRANT USAGE ON SCHEMA public TO n8n_user;
GRANT CREATE ON SCHEMA public TO n8n_user;

-- Set default privileges for future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO n8n_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO n8n_user;

-- Optimize PostgreSQL settings for n8n workload
-- These are session-level settings that can be applied without superuser privileges

-- Improve performance for n8n's workflow execution patterns
SET work_mem = '32MB';
SET maintenance_work_mem = '128MB';
SET effective_cache_size = '256MB';
SET random_page_cost = 1.1;

-- Optimize for frequent reads and writes
SET checkpoint_completion_target = 0.9;
SET wal_buffers = '16MB';

-- Create performance monitoring function
CREATE OR REPLACE FUNCTION get_db_stats()
RETURNS TABLE(
    stat_name TEXT,
    stat_value BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        'active_connections'::TEXT,
        COUNT(*)::BIGINT
    FROM pg_stat_activity 
    WHERE state = 'active'
    
    UNION ALL
    
    SELECT 
        'total_connections'::TEXT,
        COUNT(*)::BIGINT
    FROM pg_stat_activity
    
    UNION ALL
    
    SELECT 
        'database_size_mb'::TEXT,
        (pg_database_size(current_database()) / 1024 / 1024)::BIGINT;
END;
$$ LANGUAGE plpgsql;

-- Create indexes that n8n commonly uses (will be created after n8n starts)
-- This is just a placeholder for future optimization

-- Log successful initialization
INSERT INTO pg_stat_statements_info (dealloc) VALUES (0) ON CONFLICT DO NOTHING;

-- Display initialization status
SELECT 
    'n8n database initialized successfully' as status,
    current_database() as database_name,
    current_user as current_user,
    version() as postgres_version;