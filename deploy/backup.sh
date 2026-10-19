#!/usr/bin/env bash
# T08 / T06-D8: daily database backup, keep the 3 newest copies.
# Backups live on the same VPS (accepted risk in the T06 spec: the catalog
# can be re-imported; favorites live on user devices).
#
# Cron example (daily at 03:15):
#   15 3 * * * cd /opt/lovi-etown/deploy && ./backup.sh >> /var/log/lovi-backup.log 2>&1
set -euo pipefail

cd "$(dirname "$0")"
BACKUP_DIR="${BACKUP_DIR:-./backups}"
KEEP=3
mkdir -p "$BACKUP_DIR"

STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="$BACKUP_DIR/catalog-$STAMP.sql.gz"

docker compose -f compose.prod.yml --env-file .env.prod exec -T db \
  sh -c 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB"' | gzip > "$OUT"

echo "Backup written: $OUT ($(du -h "$OUT" | cut -f1))"

# Retain only the newest $KEEP backups.
ls -1t "$BACKUP_DIR"/catalog-*.sql.gz 2>/dev/null | tail -n +$((KEEP + 1)) | xargs -r rm -f
echo "Retained the $KEEP newest backups in $BACKUP_DIR."
