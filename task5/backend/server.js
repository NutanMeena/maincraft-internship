require('dotenv').config();
const express = require('express');
const { Pool } = require('pg');
const { createClient } = require('redis');
const client = require('prom-client');

const app = express();
app.use(express.json());

const PORT = process.env.APP_PORT || 8080;
const INSTANCE_ID = process.env.HOSTNAME || 'backend-unknown';

// ---------- Prometheus metrics ----------
const register = new client.Registry();
client.collectDefaultMetrics({ register });

const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
});
register.registerMetric(httpRequestDuration);

app.use((req, res, next) => {
  const end = httpRequestDuration.startTimer();
  res.on('finish', () => {
    end({ method: req.method, route: req.path, status_code: res.statusCode });
  });
  next();
});

// ---------- Postgres ----------
const pool = new Pool({
  host: process.env.DB_HOST || 'postgres',
  port: process.env.DB_PORT || 5432,
  user: process.env.DB_USER || 'admin',
  password: process.env.DB_PASSWORD || 'password',
  database: process.env.DB_NAME || 'ecommerce',
  max: 10,
  idleTimeoutMillis: 30000,
});

// ---------- Redis ----------
const redisClient = createClient({
  url: `redis://${process.env.REDIS_HOST || 'redis'}:${process.env.REDIS_PORT || 6379}`,
});
redisClient.on('error', (err) => console.error('Redis Client Error', err));

let redisReady = false;
(async () => {
  try {
    await redisClient.connect();
    redisReady = true;
    console.log('Connected to Redis');
  } catch (err) {
    console.error('Failed to connect to Redis:', err.message);
  }
})();

// ---------- Routes ----------
app.get('/', (req, res) => {
  res.json({ message: 'E-Commerce backend API', instance: INSTANCE_ID });
});

// Liveness/health check used by Docker healthcheck, Nginx and CI/CD
app.get('/health', async (req, res) => {
  const status = { status: 'ok', instance: INSTANCE_ID, checks: {} };
  let healthy = true;

  try {
    await pool.query('SELECT 1');
    status.checks.postgres = 'ok';
  } catch (err) {
    status.checks.postgres = 'failed';
    healthy = false;
  }

  try {
    if (redisReady) {
      await redisClient.ping();
      status.checks.redis = 'ok';
    } else {
      throw new Error('not connected');
    }
  } catch (err) {
    status.checks.redis = 'failed';
    healthy = false;
  }

  status.status = healthy ? 'ok' : 'degraded';
  res.status(healthy ? 200 : 503).json(status);
});

// Sample product listing, cached in Redis for 30s
app.get('/api/products', async (req, res) => {
  try {
    const cacheKey = 'products:all';
    if (redisReady) {
      const cached = await redisClient.get(cacheKey);
      if (cached) {
        return res.json({ source: 'cache', instance: INSTANCE_ID, data: JSON.parse(cached) });
      }
    }

    const result = await pool.query('SELECT id, name, price, stock FROM products ORDER BY id');
    if (redisReady) {
      await redisClient.set(cacheKey, JSON.stringify(result.rows), { EX: 30 });
    }
    res.json({ source: 'db', instance: INSTANCE_ID, data: result.rows });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to fetch products' });
  }
});

app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

app.listen(PORT, () => {
  console.log(`Backend listening on port ${PORT} (instance ${INSTANCE_ID})`);
});
