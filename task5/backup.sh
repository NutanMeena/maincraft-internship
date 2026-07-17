#!/bin/bash
# backup.sh — Automated backup for PostgreSQL and Redis data.
# Usage: ./backup.sh [retention_days]

set -euo pipefail

BACKUP_DIR="./backups"
RETENTION_DAYS="${1:-7}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

DB_CONTAINER="postgres"
REDIS_CONTAINER="redis"

# Load env vars (DB_USER, DB_NAME) if present
if [ -f .env ]; then
  set -a
  source .env
  set +a
fi

DB_USER="${DB_USER:-admin}"

mkdir -p "$BACKUP_DIR"

echo "[$(date)] Starting backup..."

# ---------- PostgreSQL backup ----------
PG_BACKUP_FILE="$BACKUP_DIR/postgres_${TIMESTAMP}.sql"
if docker exec "$DB_CONTAINER" pg_dumpall -U "$DB_USER" > "$PG_BACKUP_FILE"; then
  gzip "$PG_BACKUP_FILE"
  echo "[$(date)] PostgreSQL backup saved: ${PG_BACKUP_FILE}.gz"
else
  echo "[$(date)] ERROR: PostgreSQL backup failed" >&2
  exit 1
fi

# ---------- Redis backup (copy RDB snapshot out of the container) ----------
REDIS_BACKUP_FILE="$BACKUP_DIR/redis_${TIMESTAMP}.rdb"
if docker exec "$REDIS_CONTAINER" redis-cli SAVE > /dev/null; then
  docker cp "${REDIS_CONTAINER}:/data/dump.rdb" "$REDIS_BACKUP_FILE"
  gzip "$REDIS_BACKUP_FILE"
  echo "[$(date)] Redis backup saved: ${REDIS_BACKUP_FILE}.gz"
else
  echo "[$(date)] WARNING: Redis SAVE failed, skipping Redis backup" >&2
fi

# ---------- Cleanup backups older than retention period ----------
find "$BACKUP_DIR" -type f -name "*.gz" -mtime "+${RETENTION_DAYS}" -print -delete | while read -r f; do
  echo "[$(date)] Removed old backup: $f"
done

echo "[$(date)] Backup complete."
