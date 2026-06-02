#!/bin/bash
# Vault Raft Snapshot Backup Script
# Usage: ./backup.sh [VAULT_ADDR] [VAULT_TOKEN] [BACKUP_DIR]

set -euo pipefail

VAULT_ADDR="${1:-https://vault.lab.mecan.ir}"
VAULT_TOKEN="${2:-your-root-token-here}"
BACKUP_DIR="${3:-./backups}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
SNAP_FILE="$BACKUP_DIR/vault-snapshot-$TIMESTAMP.snap"

mkdir -p "$BACKUP_DIR"

# Check cluster health before backup
HEALTH=$(curl -sf "$VAULT_ADDR/v1/sys/health" 2>/dev/null) || {
  echo "ERROR: Vault not reachable at $VAULT_ADDR"
  exit 1
}

SEALED=$(echo "$HEALTH" | python3 -c "import sys,json; print(json.load(sys.stdin)['sealed'])")
if [ "$SEALED" = "True" ]; then
  echo "ERROR: Vault is sealed — cannot backup"
  exit 1
fi

# Take snapshot
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Taking snapshot..."
HTTP_STATUS=$(curl -s -o "$SNAP_FILE" -w "%{http_code}" \
  "$VAULT_ADDR/v1/sys/storage/raft/snapshot" \
  -H "X-Vault-Token: $VAULT_TOKEN")

if [ "$HTTP_STATUS" != "200" ]; then
  echo "ERROR: Snapshot failed (HTTP $HTTP_STATUS)"
  rm -f "$SNAP_FILE"
  exit 1
fi

SIZE=$(du -h "$SNAP_FILE" | cut -f1)
SHA=$(sha256sum "$SNAP_FILE" | cut -d' ' -f1)

echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Snapshot saved:"
echo "  File:   $SNAP_FILE"
echo "  Size:   $SIZE"
echo "  SHA256: $SHA"

# Write checksum file
echo "$SHA  $(basename $SNAP_FILE)" > "$SNAP_FILE.sha256"

# Cleanup old snapshots
if [ "$RETENTION_DAYS" -gt 0 ]; then
  DELETED=$(find "$BACKUP_DIR" -name "*.snap" -mtime "+$RETENTION_DAYS" -delete -print | wc -l)
  [ "$DELETED" -gt 0 ] && echo "  Cleaned up $DELETED snapshots older than $RETENTION_DAYS days"
fi
