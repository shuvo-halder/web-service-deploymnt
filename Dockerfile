# Stage 1: Build environment
FROM node:20.11.1-alpine3.19 AS builder
WORKDIR /usr/src/app
COPY package*.json ./
RUN npm ci --only=production

# Stage 2: Production environment
FROM node:20.11.1-alpine3.19
LABEL maintainer="your-email@example.com" \
      org.opencontainers.image.source="https://github.com/your-username/repo"

WORKDIR /usr/src/app

# Copy dependencies from builder
COPY --from=builder /usr/src/app/node_modules ./node_modules
COPY . .

# Set non-root user (node user is built-in for official node images)
USER node

# Environment variables
ENV PORT=8080
ENV NODE_ENV=production

EXPOSE 8080

# Healthcheck
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

CMD ["node", "server.js"]