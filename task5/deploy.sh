#!/bin/bash
# deploy.sh — Zero-downtime rolling deployment.
#
# Strategy: because Nginx load-balances across backend_1 and backend_2,
# we rebuild and restart one backend replica at a time so the other keeps
# serving traffic. If health checks fail after updating a replica, we roll
# back to the previous image for that service.

set -uo pipefail

LOG_FILE="./deploy.log"
COMPOSE="docker compose"

log() {
  echo "[$(date)] $*" | tee -a "$LOG_FILE"
}

rollback() {
  local service="$1"
  local previous_image="$2"
  log "ERROR: Health check failed after updating $service. Rolling back..."
  docker tag "$previous_image" "$(docker inspect --format='{{.Config.Image}}' "$service")" 2>/dev/null || true
  $COMPOSE up -d --no-deps "$service"
  log "Rollback of $service attempted. Please investigate before retrying."
  exit 1
}

log "=== Starting deployment ==="

log "Pulling latest code..."
git pull || log "WARNING: git pull failed or not a git repository; continuing with local files."

log "Building images..."
$COMPOSE build

log "Starting/updating supporting services (db, cache, monitoring, proxy front-end)..."
$COMPOSE up -d postgres redis prometheus grafana node-exporter cadvisor frontend

# ---------- Rolling update of backend replicas ----------
for SERVICE in backend_1 backend_2; do
  log "Snapshotting current image for $SERVICE (for rollback safety)..."
  PREV_IMAGE=$(docker inspect --format='{{.Config.Image}}' "$SERVICE" 2>/dev/null || echo "")

  log "Updating $SERVICE ..."
  $COMPOSE up -d --no-deps --build "$SERVICE"

  log "Waiting for $SERVICE to become healthy..."
  RETRIES=10
  HEALTHY=false
  for i in $(seq 1 $RETRIES); do
    STATE=$(docker inspect --format='{{.State.Health.Status}}' "$SERVICE" 2>/dev/null || echo "unknown")
    if [ "$STATE" == "healthy" ]; then
      HEALTHY=true
      break
    fi
    sleep 3
  done

  if [ "$HEALTHY" != "true" ]; then
    if [ -n "$PREV_IMAGE" ]; then
      rollback "$SERVICE" "$PREV_IMAGE"
    else
      log "ERROR: $SERVICE failed health check and no previous image recorded to roll back to."
      exit 1
    fi
  fi

  log "$SERVICE updated and healthy."
done

log "Updating reverse proxy..."
$COMPOSE up -d --no-deps --build nginx

log "Running final full-stack health verification..."
if ./healthcheck.sh; then
  log "=== Deployment succeeded with zero downtime ==="
else
  log "=== Deployment verification FAILED. Manual intervention required. ==="
  exit 1
fi
