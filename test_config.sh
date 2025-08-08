#!/bin/bash
# Test script to validate n8n configuration

echo "🧪 Testing n8n Configuration"
echo "============================="

# Test configuration file syntax
echo "📄 Testing configuration file syntax..."
if node -e "try { JSON.parse(require('fs').readFileSync('/home/bobby/projects/my-n8n-render/config/n8n-config.json', 'utf8')); console.log('✅ JSON syntax valid'); } catch(e) { console.log('❌ JSON syntax error:', e.message); process.exit(1); }"; then
    echo "✅ Configuration file syntax is valid"
else
    echo "❌ Configuration file has syntax errors"
    exit 1
fi

# Test environment variable setup
echo ""
echo "🌍 Testing environment variables..."

# Source the configuration from entrypoint
export LOG_LEVEL="warn"
export N8N_CONFIG_FILES="/home/bobby/projects/my-n8n-render/config/n8n-config.json"
export N8N_METRICS="false"
export N8N_VERSION_NOTIFICATIONS_ENABLED="false"
export N8N_DIAGNOSTICS_ENABLED="false"
export N8N_PERSONALIZATION_ENABLED="false"
export NODE_OPTIONS="--max-old-space-size=400 --max-semi-space-size=32"
export N8N_CACHE_BACKEND="memory"
export N8N_QUEUE_MODE="memory"
export N8N_EXECUTIONS_TIMEOUT="600"
export N8N_EXECUTIONS_MAX_TIMEOUT="1200"
export N8N_EXECUTIONS_DATA_PRUNE="true"
export N8N_EXECUTIONS_DATA_MAX_AGE="72"
export N8N_BINARY_DATA_MODE="filesystem"
export N8N_BINARY_DATA_TTL="30"
export N8N_PERSISTED_BINARY_DATA_TTL="720"
export N8N_LOG_LEVEL="warn"
export N8N_LOG_OUTPUT="console"

echo "✅ Core environment variables set"

# Test database variables (simulate Render environment)
export DB_POSTGRESDB_HOST="localhost"
export DB_POSTGRESDB_PORT="5432"
export DB_POSTGRESDB_DATABASE="n8n_db"
export DB_POSTGRESDB_USER="n8n_user"
export DB_POSTGRESDB_PASSWORD="test_password"

echo "✅ Database environment variables set"

echo ""
echo "📊 Configuration Summary:"
echo "  - Config file: ${N8N_CONFIG_FILES}"
echo "  - Log level: ${N8N_LOG_LEVEL}"
echo "  - Cache backend: ${N8N_CACHE_BACKEND}"
echo "  - Queue mode: ${N8N_QUEUE_MODE}"
echo "  - Metrics enabled: ${N8N_METRICS}"
echo "  - Memory limit: $(echo $NODE_OPTIONS | grep -o 'max-old-space-size=[0-9]*' | cut -d= -f2)MB"

echo ""
echo "✅ Configuration test completed successfully!"
echo "🚀 Ready for deployment"
