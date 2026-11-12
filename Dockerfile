FROM node:20.11.1-alpine3.19 AS builder
WORKDIR /usr/src/app
COPY package*.json ./
RUN npm install --omit=dev

FROM node:20.11.1-alpine3.19
LABEL maintainer="shuvo-halder@outlook.com" \
      org.opencontainers.image.source="https://github.com/shuvo-halder/web-service-deploymnt"

WORKDIR /usr/src/app

COPY --from=builder /usr/src/app/node_modules ./node_modules
COPY . .

USER node

ENV PORT=8080
ENV NODE_ENV=production

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

CMD ["node", "server.js"]