// backend/config.js
// ============================================================
// Backend Configuration
// ============================================================

const config = {
  port: process.env.PORT || 8080,

  // CORS: allow the frontend ALB domain, or all origins in dev
  cors: {
    origin: process.env.CORS_ORIGIN
      ? process.env.CORS_ORIGIN.split(',').map(o => o.trim())
      : (process.env.NODE_ENV === 'production'
          ? [] // Will be overridden by CORS_ORIGIN env var in ECS task definition
          : ['http://localhost:3000']),
    methods: ['GET', 'POST', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
    credentials: true,
  },

  nodeEnv: process.env.NODE_ENV || 'development',
};

module.exports = config;
