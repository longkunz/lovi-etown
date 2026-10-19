#!/usr/bin/env bash
# T08: restore a backup into a SEPARATE database for verification
# (the T08 acceptance drill: restore -> compare catalog/IDs -> drop).
# This script refuses to restore into the production database name.
#
# Usage:
#   ./restore.sh backups/catalog-20261019-031500.sql.gz catalog_verify
set -euo pipefail

cd "$(dirname "$0")"

FILE="${1:?usage: restore.sh <backup.sql.gz> <target-db-name>}"
TARGET_DB="${2:?usage: restore.sh <backup.sql.gz> <target-db-name>}"
PROD_DB="${POSTGRES_DB:-camera_catalog}"

if [ "$TARGET_DB" = "$PROD_DB" ]; then
  echo "Refusing to restore into the production database '$PROD_DB'." >&2
  echo "Pick a separate verification database name." >&2
  exit 1
fi
if [ ! -f "$FILE" ]; then
  echo "Backup file not found: $FILE" >&2
  exit 1
fi

echo "Creating database '$TARGET_DB' (dropped first if it exists)..."
docker compose -f compose.prod.yml --env-file .env.prod exec -T db \
  sh -c "dropdb -U \"\$POSTGRES_USER\" --if-exists '$TARGET_DB' && createdb -U \"\$POSTGRES_USER\" '$TARGET_DB'"

echo "Restoring $FILE into '$TARGET_DB'..."
gunzip -c "$FILE" | docker compose -f compose.prod.yml --env-file .env.prod exec -T db \
  sh -c "psql -v ON_ERROR_STOP=1 -U \"\$POSTGRES_USER\" -d '$TARGET_DB'" > /dev/null

echo "Row counts in restored database (compare with production):"
docker compose -f compose.prod.yml --env-file .env.prod exec -T db \
  sh -c "psql -U \"\$POSTGRES_USER\" -d '$TARGET_DB' -c \"SELECT 'cameras' AS table_name, COUNT(*) FROM cameras;\""

echo "Done. Drop the verification database when finished:"
echo "  docker compose -f compose.prod.yml --env-file .env.prod exec db dropdb -U postgres $TARGET_DB"
