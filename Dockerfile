# Stage 1: Build
FROM node:18-alpine AS builder
WORKDIR /app

# Copy only package files for better caching
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

# Stage 2: Runtime
FROM gcr.io/distroless/nodejs18-debian11
WORKDIR /app

# Copy built app
COPY --from=builder /app/node_modules ./node_modules
COPY --chown=nonroot:nonroot . .

USER nonroot
EXPOSE 5678

# Health check via n8n's built-in endpoint
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:5678/healthz', (res) => { process.exit(res.statusCode === 200 ? 0 : 1) })"

ENTRYPOINT ["node", "packages/cli/bin/n8n"]