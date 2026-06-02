# Level 17 — Backup & Restore (Raft Snapshots)

### Requirements:
  - **Vault Service is Running** from level 15
  - **Vault Address:** `https://vault.lab.mecan.ir`
  - **Auth:** Root token `your-root-token-here` (dev mode only)
  - **Tools:** install `jq` command

---

## Overview

Vault with Raft Integrated Storage maintains all data — secrets, policies, auth
methods, leases — in a replicated `vault.db` file on each node. A **Raft snapshot**
captures a consistent point-in-time image of this entire state in a single portable file.

```
Vault Cluster ──── GET /v1/sys/storage/raft/snapshot ──── snapshot.snap (binary)

snapshot.snap ──── POST /v1/sys/storage/raft/snapshot-force ──── Vault state rolled back
```

Snapshots include:
- All secrets (KV, PKI certs, dynamic lease metadata, etc.)
- All policies
- All auth method configurations
- All token metadata
- Raft log and cluster state

Snapshots do **not** include:
- Unseal keys (stored separately — never in Vault itself)
- Audit log files

---

## 17.1 Take a Snapshot

Only the **active leader** can serve snapshots. Follower nodes return a redirect.

```bash
ROOT_TOKEN="your-root-token-here"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

curl -s http://localhost:8210/v1/sys/storage/raft/snapshot \
  -H "X-Vault-Token: $ROOT_TOKEN" \
  -o "vault-snapshot-$TIMESTAMP.snap"

# Save a checksum for integrity verification
sha256sum "vault-snapshot-$TIMESTAMP.snap" > "vault-snapshot-$TIMESTAMP.snap.sha256"
```

Result:
```
vault-snapshot-20260531-205059.snap       17K
vault-snapshot-20260531-205059.snap.sha256
```

The snapshot is a binary file (BoltDB format). Do not edit it.

---

## 17.2 Restore from Snapshot

Two restore endpoints:

| Endpoint | Behavior |
|---|---|
| `POST /v1/sys/storage/raft/snapshot` | Validates cluster ID matches — safe restore |
| `POST /v1/sys/storage/raft/snapshot-force` | Skips cluster ID check — use for disaster recovery |

Use `snapshot-force` when restoring to a different cluster or after total data loss.

```bash
# Verify checksum first
sha256sum -c vault-snapshot-20260531-205059.snap.sha256

# Restore
curl -s -X POST http://localhost:8210/v1/sys/storage/raft/snapshot-force \
  -H "X-Vault-Token: $ROOT_TOKEN" \
  --data-binary @vault-snapshot-20260531-205059.snap
# HTTP 204 = success, empty response body
```

**After restore:** All nodes in the cluster immediately roll back to the snapshot
state. No restarts required. The cluster continues serving requests.

---

## 17.3 Test Results

### Setup
- Write 3 secrets and 1 policy → take snapshot
- Write 3 more secrets and 1 bad policy → restore snapshot

### Result after restore

| Item | Expected | Result |
|---|---|---|
| `pre-backup/secret-1` | exists | ✅ exists |
| `pre-backup/secret-2` | exists | ✅ exists |
| `pre-backup/secret-3` | exists | ✅ exists |
| `post-backup/secret-A` | gone | ✅ gone |
| `post-backup/secret-B` | gone | ✅ gone |
| `backup-test-policy` | exists | ✅ exists |
| `bad-policy` | gone | ✅ gone |

All pre-snapshot data and configuration was restored exactly. All post-snapshot
changes were rolled back completely.

---

## 17.4 Automated Backup Script

`vault-ha/scripts/backup.sh`:

```bash
#!/bin/bash
# Usage: ./backup.sh [VAULT_ADDR] [VAULT_TOKEN] [BACKUP_DIR]
# Env:   RETENTION_DAYS=30 (default)

VAULT_ADDR="${1:-http://localhost:8210}"
VAULT_TOKEN="${2:-...}"
BACKUP_DIR="${3:-./backups}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
SNAP_FILE="$BACKUP_DIR/vault-snapshot-$TIMESTAMP.snap"

mkdir -p "$BACKUP_DIR"

# Health check before backup
HEALTH=$(curl -sf "$VAULT_ADDR/v1/sys/health")
SEALED=$(echo "$HEALTH" | python3 -c "import sys,json; print(json.load(sys.stdin)['sealed'])")
[ "$SEALED" = "True" ] && { echo "ERROR: Vault is sealed"; exit 1; }

# Snapshot
curl -s -o "$SNAP_FILE" -w "%{http_code}" \
  "$VAULT_ADDR/v1/sys/storage/raft/snapshot" \
  -H "X-Vault-Token: $VAULT_TOKEN"

# Checksum
sha256sum "$SNAP_FILE" > "$SNAP_FILE.sha256"

# Cleanup old snapshots
find "$BACKUP_DIR" -name "*.snap" -mtime "+$RETENTION_DAYS" -delete
```

Run on a cron schedule:
```cron
0 */6 * * *  /opt/vault/scripts/backup.sh >> /var/log/vault-backup.log 2>&1
```

---

## 17.5 Restore Script

`vault-ha/scripts/restore.sh`:

```bash
#!/bin/bash
# Usage: ./restore.sh <snapshot_file> [vault_addr] [vault_token]

SNAP_FILE="$1"
VAULT_ADDR="${2:-http://localhost:8210}"
VAULT_TOKEN="${3:-...}"

# Verify checksum
sha256sum -c "$SNAP_FILE.sha256" || { echo "Checksum mismatch"; exit 1; }

echo "WARNING: All changes after the snapshot will be lost."
read -r -p "Type 'yes' to confirm: " CONFIRM
[ "$CONFIRM" = "yes" ] || exit 0

curl -X POST "$VAULT_ADDR/v1/sys/storage/raft/snapshot-force" \
  -H "X-Vault-Token: $VAULT_TOKEN" \
  --data-binary @"$SNAP_FILE"
# HTTP 204 = success
```

---

## 17.6 Production Backup Strategy

### What to backup

| Artifact | How | Frequency |
|---|---|---|
| **Raft snapshot** | `GET /v1/sys/storage/raft/snapshot` | Every 6h |
| **Unseal keys** | Manual — written at init time | Keep offline, never rotate unless re-keying |
| **Root token** | Manual — store in a safe, revoke after setup | Keep offline |
| **TLS certificates** | Vault PKI can reissue; back up config | With snapshot |
| **Audit logs** | Filesystem backup of `/vault/logs/` | Per your retention policy |

### Backup storage

```
backups/
├── vault-snapshot-20260531-000000.snap       ← keep 30 days
├── vault-snapshot-20260531-000000.snap.sha256
├── vault-snapshot-20260531-060000.snap
├── vault-snapshot-20260531-060000.snap.sha256
└── ...
```

Store snapshots off-cluster:
- S3 / GCS / Azure Blob (encrypted at rest)
- A separate machine not in the Vault network
- Never on the same disk as Vault data

### Restore decision tree

```
Data loss detected
        │
        ├── Partial (some nodes down) → Raft auto-heals when nodes rejoin
        │
        ├── Leader lost → Raft elects new leader in seconds
        │
        └── Total loss (all nodes + volumes gone)
              │
              ├── Restore latest snapshot
              ├── Re-initialize new cluster with same unseal keys? No
              ├── docker compose up (fresh volumes)
              ├── vault operator init (new unseal keys + root token)
              └── vault operator raft snapshot restore --force snapshot.snap
```

---

## 17.7 Verify a Snapshot Without Restoring

Inspect snapshot contents using the `vault` CLI (if available):

```bash
vault operator raft snapshot inspect snapshot.snap
```

Output shows:
- Snapshot size
- Number of keys
- Cluster ID
- Timestamp

---

## API Reference

| Operation | Method | Path |
|---|---|---|
| Take snapshot | GET | `/v1/sys/storage/raft/snapshot` |
| Restore (same cluster) | POST | `/v1/sys/storage/raft/snapshot` |
| Restore (force / DR) | POST | `/v1/sys/storage/raft/snapshot-force` |
| Raft peer list | GET | `/v1/sys/storage/raft/configuration` |
| Remove peer | POST | `/v1/sys/storage/raft/remove-peer` |
