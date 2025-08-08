# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Architecture Overview

This is an n8n GitOps deployment system optimized for Render's free tier. The core architecture follows a container-based deployment pattern with automated workflow and credential management.

**Key Components:**
- **entrypoint.sh**: Main initialization script that imports workflows/credentials on startup
- **database-adapter.sh**: Multi-backend database support (PostgreSQL/SQLite) with auto-detection
- **Dockerfile**: Multi-stage production build optimized for free tier memory constraints (400MB)
- **render.yaml**: Infrastructure-as-code configuration for Render deployment
- **config/n8n-config.json**: n8n runtime configuration with free-tier optimizations

**Data Flow:**
1. Git push triggers Render auto-deployment
2. Container builds with workflows/ and credentials/ directories
3. entrypoint.sh runs database initialization via adapter pattern
4. Workflows and encrypted credentials auto-import on startup
5. n8n starts with optimized settings for free tier constraints

## Database Architecture

The system uses an adapter pattern supporting multiple backends:
- **PostgreSQL (Render)**: Primary production database using Render's managed PostgreSQL
- **PostgreSQL (URL)**: Alternative for external providers (Neon, Supabase)  
- **SQLite**: Fallback for development/testing

Database configuration is auto-detected from environment variables with fallback logic.

## Common Development Commands

### Deployment and Health
```bash
# Validate deployment configuration
./scripts/validate-deployment.sh

# Check container health
./check_health.sh

# Test database connection  
./scripts/database-adapter.sh
```

### Workflow Management
```bash
# Import workflows manually
./import_workflows.sh /path/to/workflows

# Export current workflows
./export_workflows.sh
```

### Database Operations
```bash
# Initialize database (auto-detected backend)
./scripts/database-adapter.sh

# PostgreSQL-specific setup
./scripts/setup-database.sh
```

## Directory Structure

- **workflows/**: JSON workflow files auto-imported on deployment
- **credentials/**: Encrypted credential files (safe to commit)
- **scripts/**: Database initialization and validation utilities  
- **config/**: n8n configuration with free-tier optimizations
- **ISSUE_TEMPLATE/**: GitHub issue templates for workflows

## Free Tier Optimizations

The system is specifically optimized for Render's free tier limitations:
- Memory limit: 512MB (n8n configured for 400MB max)
- CPU throttling after 15min inactivity
- Cold start handling with extended health check timeouts
- Execution timeouts: 600s (max 1200s)
- Data pruning: 72 hours retention
- Binary data TTL: 30 days

## Environment Variables

Critical variables set in render.yaml:
- `DB_POSTGRESDB_*`: Database connection parameters
- `N8N_ENCRYPTION_KEY`: For credential encryption/decryption
- `WEBHOOK_URL`: Public webhook endpoint
- `NODE_OPTIONS`: Memory optimization settings

## Security Considerations

- Credentials are encrypted before storage using N8N_ENCRYPTION_KEY
- Database connections use SSL where supported
- Basic auth enabled by default for production
- Sensitive nodes (executeCommand, filesReadWrite) excluded from execution
- No plaintext secrets stored in repository

## Troubleshooting

Common issues and solutions:
- **502 errors**: Usually cold starts, wait 60+ seconds
- **Import failures**: Verify JSON structure in workflows/credentials
- **Database connection**: Check Render environment variable configuration
- **Memory issues**: Monitor NODE_OPTIONS memory settings