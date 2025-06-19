# Simplified Production Dockerfile
FROM node:18-alpine

WORKDIR /app

# Install system dependencies and TypeScript runtime
RUN apk add --no-cache curl && \
    npm install -g tsx

# Copy package files and install dependencies
COPY package*.json ./
RUN npm ci --production=false

# Copy application source
COPY . .

# Build frontend assets if they don't exist
RUN if [ ! -d "client/dist" ]; then npm run build; fi

# Create non-root user
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nodejs && \
    chown -R nodejs:nodejs /app

USER nodejs

# Environment variables
ENV NODE_ENV=production
ENV PORT=5000

EXPOSE 5000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:5000/api/health || exit 1

# Start the server
CMD ["tsx", "server/index.ts"]