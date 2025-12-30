#!/bin/sh
# PostgreSQL Backup Script for Docker Container
# Runs automated backups with retention policy

set -e

BACKUP_DIR="/backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/backup-${TIMESTAMP}.sql.gz"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"

echo "[$(date)] Starting PostgreSQL backup..."

# Wait for PostgreSQL to be ready
until pg_isready -h "${POSTGRES_HOST}" -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" > /dev/null 2>&1; do
  echo "Waiting for PostgreSQL to be ready..."
  sleep 2
done

# Create backup directory if it doesn't exist
mkdir -p "${BACKUP_DIR}"

# Perform backup using pg_dumpall (includes all databases, roles, and tablespaces)
echo "[$(date)] Creating backup: ${BACKUP_FILE}"
pg_dumpall -h "${POSTGRES_HOST}" -U "${POSTGRES_USER}" | gzip > "${BACKUP_FILE}"

# Check if backup was successful
if [ $? -eq 0 ]; then
  BACKUP_SIZE=$(du -h "${BACKUP_FILE}" | cut -f1)
  echo "[$(date)] Backup completed successfully: ${BACKUP_FILE} (${BACKUP_SIZE})"
else
  echo "[$(date)] ERROR: Backup failed!"
  exit 1
fi

# Clean up old backups (older than RETENTION_DAYS)
echo "[$(date)] Removing backups older than ${RETENTION_DAYS} days..."
find "${BACKUP_DIR}" -name "backup-*.sql.gz" -type f -mtime +${RETENTION_DAYS} -delete

# List remaining backups
BACKUP_COUNT=$(find "${BACKUP_DIR}" -name "backup-*.sql.gz" -type f | wc -l)
echo "[$(date)] Retention complete. ${BACKUP_COUNT} backup(s) remaining."

# Display disk usage
echo "[$(date)] Backup directory size: $(du -sh ${BACKUP_DIR} | cut -f1)"

echo "[$(date)] Backup process finished."
