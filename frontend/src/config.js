// frontend/src/config.js
// ============================================================
// Backend URL Configuration
// ============================================================
// Priority order:
//   1. REACT_APP_BACKEND_URL env variable (injected at Docker build time)
//   2. Relative /api path (when frontend+backend share the same ALB)
//   3. localhost fallback for local development
// ============================================================

const config = {
  // In production: set REACT_APP_BACKEND_URL at Docker build time (see Dockerfile.frontend)
  // In development: runs against localhost:8080
  backendUrl:
    process.env.REACT_APP_BACKEND_URL ||
    (window.location.hostname === 'localhost'
      ? 'http://localhost:8080'
      : `${window.location.protocol}//${window.location.host}/api`),
};

export default config;
