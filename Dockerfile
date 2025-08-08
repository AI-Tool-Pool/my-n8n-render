# syntax=docker/dockerfile:1.4
# Optimized n8n Dockerfile for Render free tier with minimal warnings

# Stage 1: Base dependencies with security scanning
FROM node:20-alpine AS base
RUN apk add --no-cache \
    dumb-init \
    ca-certificates \
    tzdata \
    curl \
    bash \
    && apk upgrade --no-cache

# Stage 2: Dependencies installation with optimization
FROM base AS deps
WORKDIR /app

# Install security updates and build dependencies
RUN apk add --no-cache --virtual .build-deps \
    python3 \
    make \
    g++ \
    && rm -rf /var/cache/apk/*

# Copy .npmrc for consistent npm configuration
COPY .npmrc ./

# Install n8n with optimized flags to minimize warnings
RUN npm install -g semver@7.6.3 \
    && npm install -g n8n@1.105.4 \
    && npm cache clean --force \
    && apk del .build-deps

# Copy application files and make them executable
COPY entrypoint.sh ./entrypoint.sh
COPY config/ ./config/
COPY scripts/ ./scripts/
COPY workflows/ ./workflows/
COPY credentials/ ./credentials/

# Make scripts executable in Alpine stage where shell is available
RUN chmod +x ./entrypoint.sh ./scripts/*.sh

# Stage 3: Security scanner (optional but recommended)
FROM deps AS security-scan
RUN npm audit --audit-level=moderate || true

# Stage 4: Production runtime optimized for Render free tier
FROM node:20-alpine AS runtime
WORKDIR /app

# Install runtime dependencies for shell access and health checks
RUN apk add --no-cache \
    dumb-init \
    ca-certificates \
    tzdata \
    curl \
    bash \
    openssl \
    postgresql-client \
    sqlite \
    npm \
    && rm -rf /var/cache/apk/*

# Copy .npmrc for consistent npm configuration in runtime
COPY .npmrc ./

# Set production environment variables optimized for FREE TIER
ENV NODE_ENV=production \
    NODE_OPTIONS="--max-old-space-size=400 --max-http-header-size=81920 --enable-source-maps=false" \
    N8N_LOG_LEVEL=warn \
    N8N_LOG_OUTPUT=console \
    N8N_DISABLE_UI=false \
    N8N_PROTOCOL=http \
    N8N_PORT=5678 \
    N8N_LISTEN_ADDRESS=0.0.0.0 \
    N8N_METRICS=false \
    N8N_DIAGNOSTICS_ENABLED=false \
    N8N_VERSION_NOTIFICATIONS_ENABLED=false \
    N8N_TEMPLATES_ENABLED=true \
    N8N_ONBOARDING_FLOW_DISABLED=true \
    N8N_HIRING_BANNER_ENABLED=false \
    N8N_PERSONALIZATION_ENABLED=false \
    EXECUTIONS_PROCESS=main \
    EXECUTIONS_MODE=queue \
    EXECUTIONS_TIMEOUT=600 \
    EXECUTIONS_TIMEOUT_MAX=1200 \
    EXECUTIONS_DATA_PRUNE=true \
    EXECUTIONS_DATA_MAX_AGE=72 \
    EXECUTIONS_DATA_SAVE_ON_ERROR=all \
    EXECUTIONS_DATA_SAVE_ON_SUCCESS=none \
    N8N_BINARY_DATA_MODE=filesystem \
    N8N_BINARY_DATA_TTL=30 \
    N8N_PERSISTED_BINARY_DATA_TTL=720 \
    N8N_DEFAULT_BINARY_DATA_MODE=filesystem \
    N8N_CACHE_BACKEND=memory \
    N8N_DISABLE_PRODUCTION_MAIN_PROCESS=false \
    WEBHOOK_TUNNEL_URL="" \
    GENERIC_TIMEZONE=UTC

# Copy n8n installation from deps stage instead of reinstalling
COPY --from=deps /usr/local/lib/node_modules/n8n /usr/local/lib/node_modules/n8n
COPY --from=deps /usr/local/bin/n8n /usr/local/bin/n8n

# Copy application files with correct node:node ownership
COPY --from=deps --chown=node:node /app/entrypoint.sh ./entrypoint.sh
COPY --from=deps --chown=node:node /app/config/ ./config/
COPY --from=deps --chown=node:node /app/scripts/ ./scripts/
COPY --from=deps --chown=node:node /app/workflows/ ./workflows/
COPY --from=deps --chown=node:node /app/credentials/ ./credentials/

# Create necessary directories with proper permissions for node user
RUN mkdir -p /home/node/.n8n \
    && mkdir -p /home/node/.n8n/nodes \
    && chown -R node:node /home/node/.n8n

# Switch to node user for security
USER node

# Set working directory for n8n data
ENV N8N_USER_FOLDER=/home/node/.n8n

# Expose n8n port
EXPOSE 5678

# Optimized health check with timeout and retries for free tier
HEALTHCHECK --interval=120s --timeout=30s --start-period=180s --retries=2 \
  CMD curl -f http://localhost:5678/ || exit 1

# Use dumb-init for proper signal handling and graceful shutdown
ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["./entrypoint.sh"]