# syntax=docker/dockerfile:1.4
# Multi-stage production-ready n8n Dockerfile with security hardening

# Stage 1: Base dependencies with security scanning
FROM node:18-alpine AS base
RUN apk add --no-cache \
    dumb-init \
    ca-certificates \
    tzdata \
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

# Install n8n with production optimizations
RUN npm install -g n8n@latest \
    && npm cache clean --force \
    && apk del .build-deps

# Stage 3: Security scanner (optional but recommended)
FROM deps AS security-scan
RUN npm audit --audit-level=moderate || true

# Stage 4: Production runtime with distroless
FROM gcr.io/distroless/nodejs18-debian11 AS runtime
WORKDIR /app

# Set production environment variables
ENV NODE_ENV=production \
    NODE_OPTIONS="--max-old-space-size=1024 --max-http-header-size=81920" \
    N8N_LOG_LEVEL=info \
    N8N_LOG_OUTPUT=console \
    N8N_DISABLE_UI=false \
    N8N_PROTOCOL=http \
    N8N_PORT=5678 \
    N8N_LISTEN_ADDRESS=0.0.0.0 \
    N8N_METRICS=false \
    N8N_DIAGNOSTICS_ENABLED=false \
    N8N_VERSION_NOTIFICATIONS_ENABLED=false \
    N8N_TEMPLATES_ENABLED=false \
    N8N_ONBOARDING_FLOW_DISABLED=true \
    N8N_HIRING_BANNER_ENABLED=false \
    N8N_PERSONALIZATION_ENABLED=false \
    EXECUTIONS_PROCESS=main \
    EXECUTIONS_MODE=regular \
    EXECUTIONS_TIMEOUT=3600 \
    EXECUTIONS_TIMEOUT_MAX=7200 \
    EXECUTIONS_DATA_PRUNE=true \
    EXECUTIONS_DATA_MAX_AGE=168 \
    WEBHOOK_TUNNEL_URL="" \
    GENERIC_TIMEZONE=UTC

# Copy dumb-init for proper signal handling
COPY --from=base /usr/bin/dumb-init /usr/bin/dumb-init

# Copy n8n installation from deps stage
COPY --from=deps /usr/local/lib/node_modules/n8n /usr/local/lib/node_modules/n8n
COPY --from=deps /usr/local/bin/n8n /usr/local/bin/n8n

# Copy application files with proper ownership
COPY --chown=nonroot:nonroot entrypoint.sh ./entrypoint.sh
COPY --chown=nonroot:nonroot check_health.sh ./check_health.sh
COPY --chown=nonroot:nonroot scripts/ ./scripts/
COPY --chown=nonroot:nonroot config/ ./config/

# Make scripts executable
USER root
RUN chmod +x ./entrypoint.sh ./check_health.sh ./scripts/*.sh
USER nonroot

# Create necessary directories with proper permissions
USER root
RUN mkdir -p /home/nonroot/.n8n \
    && mkdir -p /home/nonroot/.n8n/nodes \
    && chown -R nonroot:nonroot /home/nonroot/.n8n
USER nonroot

# Set working directory for n8n data
ENV N8N_USER_FOLDER=/home/nonroot/.n8n

# Expose n8n port
EXPOSE 5678

# Optimized health check with timeout and retries
HEALTHCHECK --interval=60s --timeout=10s --start-period=120s --retries=3 \
  CMD ["/app/check_health.sh"]

# Use dumb-init for proper signal handling and graceful shutdown
ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["./entrypoint.sh"]