#!/bin/bash
# Database Adapter Pattern for n8n Multi-Backend Support
# Supports PostgreSQL, SQLite, and Neon PostgreSQL

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Database configuration detection
detect_database_config() {
    local db_type="${DB_TYPE:-auto}"
    
    echo -e "${BLUE}🔍 Detecting database configuration...${NC}"
    
    # Auto-detect based on environment variables
    if [ "$db_type" = "auto" ]; then
        if [ -n "$DATABASE_URL" ]; then
            if [[ "$DATABASE_URL" == postgres* ]]; then
                DB_TYPE="postgres"
                echo -e "${GREEN}✅ Detected PostgreSQL from DATABASE_URL${NC}"
            elif [[ "$DATABASE_URL" == sqlite* ]]; then
                DB_TYPE="sqlite"
                echo -e "${GREEN}✅ Detected SQLite from DATABASE_URL${NC}"
            fi
        elif [ -n "$DB_POSTGRESDB_HOST" ]; then
            DB_TYPE="postgresdb"
            echo -e "${GREEN}✅ Detected PostgreSQL from Render environment${NC}"
        else
            DB_TYPE="sqlite"
            echo -e "${YELLOW}⚠️  No database detected, falling back to SQLite${NC}"
        fi
    else
        echo -e "${GREEN}✅ Using configured database type: $DB_TYPE${NC}"
    fi
    
    export DB_TYPE
}

# PostgreSQL setup using individual environment variables (Render style)
setup_postgres_render() {
    echo -e "${BLUE}🐘 Setting up PostgreSQL (Render configuration)...${NC}"
    
    # Validate required environment variables
    local required_vars=("DB_POSTGRESDB_HOST" "DB_POSTGRESDB_PORT" "DB_POSTGRESDB_DATABASE" "DB_POSTGRESDB_USER" "DB_POSTGRESDB_PASSWORD")
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            echo -e "${RED}❌ Missing required environment variable: $var${NC}"
            return 1
        fi
    done
    
    # Set n8n PostgreSQL environment variables
    export DB_TYPE="postgresdb"
    export DB_POSTGRESDB_SSL="${DB_POSTGRESDB_SSL:-false}"
    export DB_POSTGRESDB_SCHEMA="${DB_POSTGRESDB_SCHEMA:-public}"
    
    echo -e "${GREEN}✅ PostgreSQL configuration ready${NC}"
    echo "   Host: $DB_POSTGRESDB_HOST"
    echo "   Port: $DB_POSTGRESDB_PORT"
    echo "   Database: $DB_POSTGRESDB_DATABASE"
    echo "   Schema: $DB_POSTGRESDB_SCHEMA"
}

# PostgreSQL setup using DATABASE_URL (Neon, Supabase, etc.)
setup_postgres_url() {
    echo -e "${BLUE}🐘 Setting up PostgreSQL (URL configuration)...${NC}"
    
    if [ -z "$DATABASE_URL" ]; then
        echo -e "${RED}❌ DATABASE_URL is required for URL-based PostgreSQL setup${NC}"
        return 1
    fi
    
    # Set n8n PostgreSQL environment variables from URL
    export DB_TYPE="postgresdb"
    export DB_POSTGRESDB_DATABASE="$DATABASE_URL"
    export DB_POSTGRESDB_SSL="${DB_POSTGRESDB_SSL:-true}"
    export DB_POSTGRESDB_SCHEMA="${DB_POSTGRESDB_SCHEMA:-public}"
    
    echo -e "${GREEN}✅ PostgreSQL URL configuration ready${NC}"
    echo "   URL: ${DATABASE_URL:0:50}..."
}

# SQLite setup for file-based persistence
setup_sqlite() {
    echo -e "${BLUE}🗃️  Setting up SQLite...${NC}"
    
    # Create SQLite data directory
    local sqlite_dir="${N8N_USER_FOLDER:-/home/nonroot/.n8n}/sqlite"
    local sqlite_file="${sqlite_dir}/database.sqlite"
    
    mkdir -p "$sqlite_dir"
    
    # Set n8n SQLite environment variables
    export DB_TYPE="sqlite"
    export DB_SQLITE_DATABASE="$sqlite_file"
    export DB_SQLITE_VACUUM_ON_STARTUP="true"
    
    # Set appropriate permissions if running as root (for setup)
    if [ "$(id -u)" = "0" ]; then
        chown -R nonroot:nonroot "$sqlite_dir" 2>/dev/null || true
        chmod 755 "$sqlite_dir"
    fi
    
    echo -e "${GREEN}✅ SQLite configuration ready${NC}"
    echo "   Database file: $sqlite_file"
    echo "   Directory: $sqlite_dir"
}

# Database connection test
test_database_connection() {
    echo -e "${BLUE}🔌 Testing database connection...${NC}"
    
    case "$DB_TYPE" in
        "postgresdb")
            if [ -n "$DATABASE_URL" ]; then
                test_postgres_url_connection
            else
                test_postgres_render_connection
            fi
            ;;
        "postgres")
            test_postgres_url_connection
            ;;
        "sqlite")
            test_sqlite_connection
            ;;
        *)
            echo -e "${RED}❌ Unknown database type: $DB_TYPE${NC}"
            return 1
            ;;
    esac
}

# Test PostgreSQL connection (Render style)
test_postgres_render_connection() {
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if PGPASSWORD="$DB_POSTGRESDB_PASSWORD" psql \
            -h "$DB_POSTGRESDB_HOST" \
            -p "$DB_POSTGRESDB_PORT" \
            -U "$DB_POSTGRESDB_USER" \
            -d "$DB_POSTGRESDB_DATABASE" \
            -c "SELECT 1;" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ PostgreSQL connection successful${NC}"
            return 0
        fi
        
        echo -e "${YELLOW}⏳ Attempt $attempt/$max_attempts: Waiting for PostgreSQL...${NC}"
        sleep 2
        ((attempt++))
    done
    
    echo -e "${RED}❌ Failed to connect to PostgreSQL after $max_attempts attempts${NC}"
    return 1
}

# Test PostgreSQL connection (URL style)
test_postgres_url_connection() {
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if psql "$DATABASE_URL" -c "SELECT 1;" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ PostgreSQL connection successful${NC}"
            return 0
        fi
        
        echo -e "${YELLOW}⏳ Attempt $attempt/$max_attempts: Waiting for PostgreSQL...${NC}"
        sleep 2
        ((attempt++))
    done
    
    echo -e "${RED}❌ Failed to connect to PostgreSQL after $max_attempts attempts${NC}"
    return 1
}

# Test SQLite connection
test_sqlite_connection() {
    local sqlite_file="$DB_SQLITE_DATABASE"
    
    # Try to create/access the SQLite database
    if sqlite3 "$sqlite_file" "SELECT 1;" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ SQLite database accessible${NC}"
        return 0
    else
        echo -e "${RED}❌ Failed to access SQLite database: $sqlite_file${NC}"
        return 1
    fi
}

# Database schema initialization
initialize_database_schema() {
    echo -e "${BLUE}🏗️  Initializing database schema...${NC}"
    
    case "$DB_TYPE" in
        "postgresdb"|"postgres")
            initialize_postgres_schema
            ;;
        "sqlite")
            initialize_sqlite_schema
            ;;
        *)
            echo -e "${RED}❌ Unknown database type for schema initialization: $DB_TYPE${NC}"
            return 1
            ;;
    esac
}

# Initialize PostgreSQL schema
initialize_postgres_schema() {
    echo -e "${BLUE}🐘 Initializing PostgreSQL schema...${NC}"
    
    # n8n will handle schema initialization automatically
    # We just need to ensure the database exists and is accessible
    echo -e "${GREEN}✅ PostgreSQL schema initialization delegated to n8n${NC}"
}

# Initialize SQLite schema
initialize_sqlite_schema() {
    echo -e "${BLUE}🗃️  Initializing SQLite schema...${NC}"
    
    # n8n will handle schema initialization automatically
    # We just need to ensure the database file is accessible
    echo -e "${GREEN}✅ SQLite schema initialization delegated to n8n${NC}"
}

# Database optimization
optimize_database() {
    echo -e "${BLUE}⚡ Optimizing database performance...${NC}"
    
    case "$DB_TYPE" in
        "postgresdb"|"postgres")
            optimize_postgres
            ;;
        "sqlite")
            optimize_sqlite
            ;;
        *)
            echo -e "${YELLOW}⚠️  No optimization available for database type: $DB_TYPE${NC}"
            ;;
    esac
}

# Optimize PostgreSQL
optimize_postgres() {
    echo -e "${BLUE}🐘 Applying PostgreSQL optimizations...${NC}"
    
    # These optimizations will be applied by n8n when it connects
    # Set connection pool settings for better performance
    export DB_POSTGRESDB_POOL_SIZE="${DB_POSTGRESDB_POOL_SIZE:-5}"
    export DB_POSTGRESDB_POOL_SIZE_MAX="${DB_POSTGRESDB_POOL_SIZE_MAX:-10}"
    
    echo -e "${GREEN}✅ PostgreSQL optimization settings configured${NC}"
}

# Optimize SQLite
optimize_sqlite() {
    echo -e "${BLUE}🗃️  Applying SQLite optimizations...${NC}"
    
    local sqlite_file="$DB_SQLITE_DATABASE"
    
    # Apply SQLite optimization settings
    if [ -f "$sqlite_file" ]; then
        sqlite3 "$sqlite_file" "PRAGMA journal_mode=WAL; PRAGMA synchronous=NORMAL; PRAGMA cache_size=10000; PRAGMA temp_store=memory;" 2>/dev/null || true
        echo -e "${GREEN}✅ SQLite optimization applied${NC}"
    else
        echo -e "${YELLOW}⚠️  SQLite file not found, optimizations will be applied on first run${NC}"
    fi
}

# Main execution function
main() {
    echo -e "${BLUE}🚀 Starting Database Adapter Configuration...${NC}"
    echo "=================================="
    
    # Detect and configure database
    detect_database_config
    
    case "$DB_TYPE" in
        "postgresdb")
            if [ -n "$DATABASE_URL" ]; then
                setup_postgres_url
            else
                setup_postgres_render
            fi
            ;;
        "postgres")
            setup_postgres_url
            ;;
        "sqlite")
            setup_sqlite
            ;;
        *)
            echo -e "${RED}❌ Unsupported database type: $DB_TYPE${NC}"
            exit 1
            ;;
    esac
    
    # Test connection
    test_database_connection
    
    # Initialize schema
    initialize_database_schema
    
    # Optimize database
    optimize_database
    
    echo "=================================="
    echo -e "${GREEN}✅ Database adapter configuration completed successfully${NC}"
    echo -e "${BLUE}Database Type: $DB_TYPE${NC}"
}

# Run main function if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi