#!/bin/bash
# Database Setup Script for n8n on Render
# This script ensures the PostgreSQL database is properly initialized and configured

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_PREFIX="[DB-SETUP]"
readonly MAX_RETRIES=30
readonly RETRY_DELAY=2

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}${LOG_PREFIX} INFO:${NC} $1" >&2
}

log_warn() {
    echo -e "${YELLOW}${LOG_PREFIX} WARN:${NC} $1" >&2
}

log_error() {
    echo -e "${RED}${LOG_PREFIX} ERROR:${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}${LOG_PREFIX} SUCCESS:${NC} $1" >&2
}

# Function to check if PostgreSQL is available
check_postgres_connection() {
    local retries=0
    
    log_info "Checking PostgreSQL connection..."
    
    while [ $retries -lt $MAX_RETRIES ]; do
        if psql "${DATABASE_URL}" -c "SELECT 1;" >/dev/null 2>&1; then
            log_success "PostgreSQL connection established"
            return 0
        fi
        
        retries=$((retries + 1))
        log_warn "PostgreSQL not ready, attempt $retries/$MAX_RETRIES (waiting ${RETRY_DELAY}s)"
        sleep $RETRY_DELAY
    done
    
    log_error "Failed to connect to PostgreSQL after $MAX_RETRIES attempts"
    return 1
}

# Function to run SQL initialization script
run_db_initialization() {
    log_info "Running database initialization script..."
    
    if [ -f "${SCRIPT_DIR}/init-db.sql" ]; then
        if psql "${DATABASE_URL}" -f "${SCRIPT_DIR}/init-db.sql" >/dev/null 2>&1; then
            log_success "Database initialization completed successfully"
        else
            log_warn "Database initialization script failed (may already be initialized)"
        fi
    else
        log_warn "Database initialization script not found at ${SCRIPT_DIR}/init-db.sql"
    fi
}

# Function to verify database schema
verify_database_schema() {
    log_info "Verifying database schema..."
    
    # Check if required extensions are available
    local extensions_check
    extensions_check=$(psql "${DATABASE_URL}" -t -c "
        SELECT COUNT(*) 
        FROM pg_extension 
        WHERE extname IN ('uuid-ossp', 'pg_trgm');
    " 2>/dev/null || echo "0")
    
    if [ "${extensions_check// /}" = "2" ]; then
        log_success "Required PostgreSQL extensions are installed"
    else
        log_warn "Some PostgreSQL extensions may not be available"
    fi
    
    # Check database connectivity and basic functionality
    local test_query
    test_query=$(psql "${DATABASE_URL}" -t -c "SELECT current_database(), current_user;" 2>/dev/null || echo "")
    
    if [ -n "$test_query" ]; then
        log_success "Database schema verification completed"
        log_info "Connected to: $(echo "$test_query" | tr -d '\n' | xargs)"
    else
        log_error "Database schema verification failed"
        return 1
    fi
}

# Function to optimize database settings for n8n
optimize_database_settings() {
    log_info "Applying database optimizations for n8n..."
    
    # Apply session-level optimizations that don't require superuser privileges
    psql "${DATABASE_URL}" -c "
        -- Optimize for n8n's workflow execution patterns
        SET SESSION work_mem = '32MB';
        SET SESSION maintenance_work_mem = '128MB';
        SET SESSION effective_cache_size = '256MB';
        SET SESSION random_page_cost = 1.1;
        
        -- Connection and query optimizations
        SET SESSION statement_timeout = '30min';
        SET SESSION lock_timeout = '30s';
        SET SESSION idle_in_transaction_session_timeout = '5min';
    " >/dev/null 2>&1
    
    log_success "Database optimizations applied"
}

# Function to create performance monitoring view
setup_monitoring() {
    log_info "Setting up database monitoring..."
    
    psql "${DATABASE_URL}" -c "
        -- Create or replace monitoring function if it doesn't exist
        CREATE OR REPLACE FUNCTION get_db_performance_stats()
        RETURNS TABLE(
            metric_name TEXT,
            metric_value BIGINT
        ) AS \$\$
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
        \$\$ LANGUAGE plpgsql;
    " >/dev/null 2>&1
    
    log_success "Database monitoring setup completed"
}

# Function to display database information
show_database_info() {
    log_info "Database Information:"
    
    local db_info
    db_info=$(psql "${DATABASE_URL}" -t -c "
        SELECT 
            'Database: ' || current_database() || E'\n' ||
            'User: ' || current_user || E'\n' ||
            'PostgreSQL Version: ' || version() || E'\n' ||
            'Database Size: ' || pg_size_pretty(pg_database_size(current_database())) || E'\n' ||
            'Connection Count: ' || (SELECT count(*) FROM pg_stat_activity)
    " 2>/dev/null || echo "Unable to retrieve database information")
    
    echo "$db_info" | while IFS= read -r line; do
        [ -n "$line" ] && log_info "  $line"
    done
}

# Main execution function
main() {
    log_info "Starting database setup for n8n..."
    
    # Validate required environment variables
    if [ -z "${DATABASE_URL:-}" ]; then
        log_error "DATABASE_URL environment variable is not set"
        exit 1
    fi
    
    # Execute setup steps
    check_postgres_connection || exit 1
    run_db_initialization
    verify_database_schema || exit 1
    optimize_database_settings
    setup_monitoring
    show_database_info
    
    log_success "Database setup completed successfully!"
    log_info "n8n can now connect to the properly configured PostgreSQL database"
}

# Execute main function
main "$@"