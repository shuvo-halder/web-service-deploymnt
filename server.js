const express = require('express');
const pino = require('pino');
const pinoHttp = require('pino-http');
const client = require('prom-client');

// Configuration from environment variables
const PORT = process.env.PORT || 8080;
const LOG_LEVEL = process.env.LOG_LEVEL || 'info';
const ENV_NAME = process.env.ENVIRONMENT || 'development';
const VERSION = process.env.npm_package_version || '1.0.0';

// Initialize structured JSON logger
const logger = pino({ level: LOG_LEVEL });
const app = express();

app.use(pinoHttp({ logger }));

// Prometheus Metrics Setup
const register = new client.Registry();
client.collectDefaultMetrics({ register });

const httpRequestDurationMicroseconds = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'code'],
  buckets: [0.1, 0.3, 0.5, 0.7, 1, 3, 5, 7, 10]
});
register.registerMetric(httpRequestDurationMicroseconds);

const httpRequestsTotal = new client.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'code']
});
register.registerMetric(httpRequestsTotal);

// Middleware to track metrics
app.use((req, res, next) => {
  const end = httpRequestDurationMicroseconds.startTimer();
  res.on('finish', () => {
    httpRequestsTotal.inc({ method: req.method, route: req.path, code: res.statusCode });
    end({ method: req.method, route: req.path, code: res.statusCode });
  });
  next();
});

// Endpoints
app.get('/', (req, res) => {
  res.json({
    message: "Hello from DevOps Task!",
    status: "running",
    version: VERSION,
    environment: ENV_NAME
  });
});

app.get('/health', (req, res) => {
  res.status(200).json({ status: 'OK', timestamp: new Date().toISOString() });
});

app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

// Export app for testing, or start server if run directly
if (require.main === module) {
  const server = app.listen(PORT, () => {
    logger.info(`Server running on port ${PORT} in ${ENV_NAME} mode`);
  });

  // Graceful shutdown on SIGTERM
  process.on('SIGTERM', () => {
    logger.info('SIGTERM signal received: closing HTTP server');
    server.close(() => {
      logger.info('HTTP server closed');
      process.exit(0);
    });
  });
}

module.exports = app;