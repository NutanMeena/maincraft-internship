#!/bin/bash
# restore.sh — Restore PostgreSQL from a compressed backup file.
# Usage: ./restore.sh ./backups/postgres_20260713_120000.sql.gz

set -euo pipefail

BACKUP_FILE="${1:-}"
DB_CONTAINER="postgres"

if [ -z "$BACKUP_FILE" ] || [ ! -f "$BACKUP_FILE" ]; then
  echo "Usage: ./restore.sh <path-to-backup.sql.gz>"
  exit 1
fi

if [ -f .env ]; then
  set -a
  source .env
  set +a
fi

DB_USER="${DB_USER:-admin}"

echo "[$(date)] WARNING: This will restore data into the running '$DB_CONTAINER' container."
read -r -p "Type 'yes' to continue: " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "Restore cancelled."
  exit 0
fi

echo "[$(date)] Restoring from $BACKUP_FILE ..."
gunzip -c "$BACKUP_FILE" | docker exec -i "$DB_CONTAINER" psql -U "$DB_USER"

echo "[$(date)] Restore complete."
