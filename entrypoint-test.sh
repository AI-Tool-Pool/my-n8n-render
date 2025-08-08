#!/bin/sh
# Test entrypoint without workflow import for debugging

set -e

# Set environment variable to enforce correct config file permissions
export N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true

echo "🚀 Starting n8n test version..."
echo "=================================="

# Initialize database using adapter pattern
if [ -f "/app/scripts/database-adapter.sh" ]; then
    echo "🗄️  Initializing database with multi-backend support..."
    /app/scripts/database-adapter.sh
    echo "✅ Database initialization completed"
elif [ -f "/app/scripts/setup-database.sh" ]; then
    echo "🗄️  Initializing PostgreSQL database (legacy mode)..."
    /app/scripts/setup-database.sh
    echo "✅ Database initialization completed"
else
    echo "📁 No database setup script found, skipping initialization"
fi

echo "=================================="
echo "🧪 SKIPPING workflow and credential import for faster testing"
echo "=================================="
echo "⚙️  Loading n8n configuration..."

# Set n8n configuration file path
export N8N_CONFIG_FILES="/app/config/n8n-config.json"

# Free tier optimizations - use environment variables instead of config file
export N8N_METRICS="false"
export N8N_VERSION_NOTIFICATIONS_ENABLED="false"
export N8N_DIAGNOSTICS_ENABLED="false"
export N8N_PERSONALIZATION_ENABLED="false"

# Memory and performance optimizations for free tier
export NODE_OPTIONS="--max-old-space-size=400 --max-semi-space-size=32"
export N8N_CACHE_BACKEND="memory"
export N8N_QUEUE_MODE="memory"

# Session configuration (using PostgreSQL instead of Redis)
export N8N_USER_MANAGEMENT_JWT_SECRET="${JWT_SECRET:-$(openssl rand -hex 32)}"
export N8N_SESSION_SECRET="${SESSION_SECRET:-$(openssl rand -hex 32)}"

# Execution limits for free tier - use environment variables
export N8N_EXECUTIONS_TIMEOUT="600"
export N8N_EXECUTIONS_MAX_TIMEOUT="1200"
export N8N_EXECUTIONS_DATA_PRUNE="true"
export N8N_EXECUTIONS_DATA_MAX_AGE="72"

# Binary data cleanup for storage efficiency - use environment variables
export N8N_BINARY_DATA_MODE="filesystem"
export N8N_BINARY_DATA_TTL="30"
export N8N_PERSISTED_BINARY_DATA_TTL="720"

# Log configuration - use environment variables
export N8N_LOG_LEVEL="${LOG_LEVEL:-warn}"
export N8N_LOG_OUTPUT="console"

echo "✅ Configuration loaded successfully"
echo "=================================="
echo "🚀 Starting n8n..."

# Start n8n with optimized settings
exec n8n start
