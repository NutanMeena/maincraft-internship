#!/bin/bash
# healthcheck.sh — Verifies that the stack is healthy after deployment.
# Exits 0 if healthy, 1 otherwise.

set -uo pipefail

if [ -f .env ]; then
  set -a
  source .env
  set +a
fi

APP_PORT="${APP_PORT:-8080}"
MAX_RETRIES=10
SLEEP_SECONDS=3

echo "[$(date)] Running health checks against http://localhost:${APP_PORT} ..."

for i in $(seq 1 "$MAX_RETRIES"); do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${APP_PORT}/health" || echo "000")
  if [ "$STATUS" == "200" ]; then
    echo "[$(date)] Backend healthy (attempt $i/$MAX_RETRIES)."
    HEALTHY=true
    break
  fi
  echo "[$(date)] Attempt $i/$MAX_RETRIES: backend not ready yet (status: $STATUS). Retrying in ${SLEEP_SECONDS}s..."
  sleep "$SLEEP_SECONDS"
done

if [ "${HEALTHY:-false}" != "true" ]; then
  echo "[$(date)] ERROR: Backend failed health check after ${MAX_RETRIES} attempts." >&2
  exit 1
fi

# Check Docker Compose reported healthy status for critical services
for SERVICE in postgres redis backend_1 backend_2 nginx; do
  STATE=$(docker inspect --format='{{.State.Health.Status}}' "$SERVICE" 2>/dev/null || echo "unknown")
  echo "  - $SERVICE: $STATE"
  if [ "$STATE" != "healthy" ] && [ "$STATE" != "unknown" ]; then
    echo "[$(date)] ERROR: $SERVICE reported unhealthy status: $STATE" >&2
    exit 1
  fi
done

echo "[$(date)] All health checks passed."
exit 0
