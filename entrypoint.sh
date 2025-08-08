#!/bin/sh
# Auto-import workflows and credentials on container startup

set -e

# Set environment variable to enforce correct config file permissions
export N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true

echo "🚀 Starting n8n with auto-import..."
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

# Define source directories
WORKFLOW_DIR="/app/workflows"
CREDENTIAL_DIR="/app/credentials"

# Import workflows if they exist
if [ -d "$WORKFLOW_DIR" ] && [ -n "$(ls -A "$WORKFLOW_DIR" 2>/dev/null)" ]; then
    echo "📁 Importing workflows..."
    for file in "$WORKFLOW_DIR"/*.json; do
        if [ -f "$file" ]; then
            echo "  → $(basename "$file")"
        fi
    done
    n8n import:workflow --input="$WORKFLOW_DIR" --separate
    echo "✅ Workflows imported successfully"
else
    echo "📁 No workflows found, skipping import"
fi

# Import credentials if they exist
if [ -d "$CREDENTIAL_DIR" ] && [ -n "$(ls -A "$CREDENTIAL_DIR" 2>/dev/null)" ]; then
    echo "🔐 Importing credentials..."
    for file in "$CREDENTIAL_DIR"/*.json; do
        if [ -f "$file" ]; then
            echo "  → $(basename "$file")"
        fi
    done
    # Use the correct n8n command for importing credentials
    n8n import:credentials --input="$CREDENTIAL_DIR" --separate
    echo "✅ Credentials imported successfully"
else
    echo "🔐 No credentials found, skipping import"
fi

echo "=================================="
echo "⚙️  Loading n8n configuration..."

# Set n8n configuration file path
export N8N_CONFIG_FILES="/app/config/n8n-config.json"

# Free tier optimizations
export N8N_METRICS_ENABLE="false"
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

# Execution limits for free tier
export N8N_EXECUTIONS_TIMEOUT="600"
export N8N_EXECUTIONS_MAX_TIMEOUT="1200"
export N8N_EXECUTIONS_DATA_PRUNE="true"
export N8N_EXECUTIONS_DATA_MAX_AGE="72"

# Binary data cleanup for storage efficiency
export N8N_BINARY_DATA_TTL="30"
export N8N_PERSISTED_BINARY_DATA_TTL="720"

# Log configuration
export N8N_LOG_LEVEL="${LOG_LEVEL:-warn}"
export N8N_LOG_OUTPUT="console"

echo "✅ Configuration loaded successfully"
echo "=================================="
echo "🚀 Starting n8n..."

# Start n8n with optimized settings
exec n8n start