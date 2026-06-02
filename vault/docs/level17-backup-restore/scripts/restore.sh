#!/bin/bash
# Vault Raft Snapshot Restore Script
# Usage: ./restore.sh <snapshot_file> [VAULT_ADDR] [VAULT_TOKEN]
# WARNING: This replaces ALL Vault data. Cannot be undone.

set -euo pipefail

SNAP_FILE="${1:?Usage: $0 <snapshot_file> [vault_addr] [vault_token]}"
VAULT_ADDR="${2:-https://vault.lab.mecan.ir}"
VAULT_TOKEN="${3:-your-root-token-here}"

[ -f "$SNAP_FILE" ] || { echo "ERROR: Snapshot file not found: $SNAP_FILE"; exit 1; }

# Verify checksum if available
SHA_FILE="$SNAP_FILE.sha256"
if [ -f "$SHA_FILE" ]; then
  echo "Verifying checksum..."
  (cd "$(dirname "$SNAP_FILE")" && sha256sum -c "$(basename "$SHA_FILE")") || { echo "ERROR: Checksum mismatch — snapshot may be corrupt"; exit 1; }
fi

SIZE=$(du -h "$SNAP_FILE" | cut -f1)
echo "Snapshot: $SNAP_FILE ($SIZE)"
echo "Target:   $VAULT_ADDR"
echo ""
echo "WARNING: This will replace ALL Vault data with the snapshot contents."
echo "All changes made after the snapshot was taken will be PERMANENTLY LOST."
echo ""
read -r -p "Type 'yes' to confirm restore: " CONFIRM
[ "$CONFIRM" = "yes" ] || { echo "Restore cancelled."; exit 0; }

echo ""
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Restoring snapshot..."

HTTP_STATUS=$(curl -s -o /tmp/restore-output.txt -w "%{http_code}" \
  -X POST "$VAULT_ADDR/v1/sys/storage/raft/snapshot-force" \
  -H "X-Vault-Token: $VAULT_TOKEN" \
  --data-binary @"$SNAP_FILE")

if [ "$HTTP_STATUS" = "204" ]; then
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Restore successful (HTTP 204)"
  echo ""
  echo "IMPORTANT: All Vault nodes must be unsealed after restore."
  echo "Use the unseal keys from your vault-ha-init.json file."
else
  echo "ERROR: Restore failed (HTTP $HTTP_STATUS)"
  cat /tmp/restore-output.txt
  exit 1
fi
