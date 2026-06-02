# Level 15 — HA with Raft Storage & Persistence

### Requirements:
  - **Cluster Ports:** `8210` (node-1), `8220` (node-2), `8230` (node-3)
  - **Init file:** `vault-ha-init.json` — keep this safe, contains unseal keys + root token
  - **Tools:** install `jq` command

---

## Overview

Production Vault is never a single node. HashiCorp Vault's **Integrated Storage (Raft)**
provides built-in HA without external dependencies like Consul. Three nodes form a
consensus cluster — one leader, two followers.

```
vault-node-1 (leader)   ──── 8210 ─── secrets, auth
vault-node-2 (follower) ──── 8220 ─── read + forward writes to leader
vault-node-3 (follower) ──── 8230 ─── read + forward writes to leader

Raft consensus port: 8201 (cluster-to-cluster, internal)
```

**Key differences from dev mode:**

| Dev mode | Production mode (Raft) |
|---|---|
| Starts pre-initialized and unsealed | Starts sealed — must init + unseal |
| Data in memory — lost on restart | Data on disk — survives restarts |
| Single node | 3+ nodes for HA |
| Fixed root token | Root token issued once at init |
| No unseal keys | Shamir's Secret: N keys, threshold T |

---

## 15.1 Directory Structure

```
level15-ha-raft-persistence/
├── compose.yml
├── vault-ha-init.json   ← created at first init — KEEP SAFE
├── config/
│   ├── vault-1.hcl
│   ├── vault-2.hcl
│   └── vault-3.hcl
└── data/
    ├── vault-1/         ← vault.db — Raft database, persists all secrets
    ├── vault-2/
    └── vault-3/
```

---

## 15.2 Node Configuration

All three nodes share the same structure. Each has a unique `node_id` and `api_addr`.

`config/vault-1.hcl`:
```hcl
storage "raft" {
  path    = "/vault/data"
  node_id = "vault-1"

  retry_join {
    leader_api_addr = "http://vault-node-1:8200"
  }
  retry_join {
    leader_api_addr = "http://vault-node-2:8200"
  }
  retry_join {
    leader_api_addr = "http://vault-node-3:8200"
  }
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = true
}

api_addr      = "http://vault-node-1:8200"
cluster_addr  = "http://vault-node-1:8201"
ui            = true
disable_mlock = true
```

`disable_mlock = true` is required in containers.  
`retry_join` tells each node where to find peers — they bootstrap each other.

---

## 15.3 Start the Cluster

**Step 1 — Create the shared network (once, if not already exists):**
```bash
docker network create app_net
```

**Step 2 — Create data directories with open permissions:**
```bash
cd docs/level15-ha-raft-persistence
mkdir -p data/{vault-1,vault-2,vault-3}
chmod 777 data/vault-1 data/vault-2 data/vault-3
```

**Step 3 — Start all nodes:**
```bash
docker compose up -d
docker compose ps
```

Expected output — all 3 containers `Up (healthy)`:
```
NAME           STATUS          PORTS
vault-node-1   Up (healthy)    0.0.0.0:8210->8200/tcp
vault-node-2   Up (healthy)    0.0.0.0:8220->8200/tcp
vault-node-3   Up (healthy)    0.0.0.0:8230->8200/tcp
```

**Step 4 — Verify all nodes are ready (not yet initialized):**
```bash
for PORT in 8210 8220 8230; do
  echo "=== Port $PORT ==="
  curl -s http://localhost:$PORT/v1/sys/health | jq '{initialized, sealed}'
done
```

Expected — all show `initialized: false, sealed: true`.

---

## 15.4 Initialization (One-Time Only)

> **Warning:** Run this **once** on **one node only**. Never run init again — it will fail and overwrite your keys file with an error message.

```bash
# Run from inside the level15 directory
cd docs/level15-ha-raft-persistence

curl -s -X POST http://localhost:8210/v1/sys/init \
  -H "Content-Type: application/json" \
  -d '{
    "secret_shares": 5,
    "secret_threshold": 3
  }' > vault-ha-init.json

cat vault-ha-init.json | jq .
```

Verify the file contains real keys, not an error:
```bash
# This must print a token, not "errors"
jq -r '.root_token' vault-ha-init.json
```

Expected response shape:
```json
{
  "keys_base64": [
    "pXQWmv3t9m9mjfZaR/a9TFr6eJmhlDmSMwJ1lJ6gp0e3",
    "stdWfvvDnbQ4BdbV/xvFqj04K6YGoypvnhfj98bmsYVz",
    "lxa/C0Y1hUevFOm9tWYvRTpshtofUiB4fobhusghrwqc",
    "uvwTeZvYLevFIFU2XV5+l313xg/SxlaRBiLXRPSMusDN",
    "PKZ0qU3tk3gqn2Pf1lUANHJxVrpcLTYheXkdE3aazQzn"
  ],
  "root_token": ""<YOUR_VAULT_ROOT_TOKEN>""
}
```

Use `keys_base64` for unsealing (not `keys`).

**Shamir's Secret Sharing:** 5 keys generated, any 3 needed to unseal.

---

## 15.5 Unsealing

After every restart, each node must be unsealed with at least 3 keys.
**Order matters: unseal node-1 first, then wait for nodes 2 and 3 to join.**

**Step 1 — Unseal node-1 (the bootstrap node):**
```bash
KEY1=$(jq -r '.keys_base64[0]' vault-ha-init.json)
KEY2=$(jq -r '.keys_base64[1]' vault-ha-init.json)
KEY3=$(jq -r '.keys_base64[2]' vault-ha-init.json)

echo "=== Unsealing node-1 (port 8210) ==="
for KEY in "$KEY1" "$KEY2" "$KEY3"; do
  curl -s -X POST http://localhost:8210/v1/sys/unseal \
    -H "Content-Type: application/json" \
    -d "{\"key\": \"$KEY\"}" | jq '{sealed, progress, t}'
done
```

After the 3rd key, `sealed` becomes `false`.

**Step 2 — Wait for node-2 and node-3 to join the cluster:**

Raft followers discover the leader via `retry_join` and replicate state.
Wait until both show `initialized: true`:

```bash
# Wait until both followers are initialized
until curl -s http://localhost:8220/v1/sys/health | jq -e '.initialized == true' > /dev/null 2>&1; do
  echo "Waiting for node-2 to join..."; sleep 2
done
echo "node-2 joined"

until curl -s http://localhost:8230/v1/sys/health | jq -e '.initialized == true' > /dev/null 2>&1; do
  echo "Waiting for node-3 to join..."; sleep 2
done
echo "node-3 joined"
```

**Step 3 — Unseal node-2 and node-3:**
```bash
for PORT in 8220 8230; do
  echo "=== Unsealing node on port $PORT ==="
  for KEY in "$KEY1" "$KEY2" "$KEY3"; do
    curl -s -X POST http://localhost:$PORT/v1/sys/unseal \
      -H "Content-Type: application/json" \
      -d "{\"key\": \"$KEY\"}" | jq '{sealed, progress, t}'
  done
done
```

**Verify all nodes are unsealed:**
```bash
for PORT in 8210 8220 8230; do
  STATUS=$(curl -s http://localhost:$PORT/v1/sys/health | jq '{initialized, sealed, standby}')
  echo "Port $PORT: $STATUS"
done
```

Expected:
```
Port 8210: { "initialized": true, "sealed": false, "standby": false }  ← leader
Port 8220: { "initialized": true, "sealed": false, "standby": true  }  ← follower
Port 8230: { "initialized": true, "sealed": false, "standby": true  }  ← follower
```

---

## 15.6 Login with Token

```bash
export ROOT_TOKEN=$(jq -r '.root_token' vault-ha-init.json)
echo "Root Token: $ROOT_TOKEN"
```

Test login:
```bash
curl -s http://localhost:8210/v1/auth/token/lookup-self \
  -H "X-Vault-Token: $ROOT_TOKEN" | jq '{request_id, data: .data | {id, policies, type}}'
```

Expected — shows the root token info:
```json
{
  "data": {
    "id": ""<YOUR_VAULT_ROOT_TOKEN>"",
    "policies": ["root"],
    "type": "service"
  }
}
```

---

## 15.7 Cluster Status

```bash
ROOT_TOKEN=$(jq -r '.root_token' vault-ha-init.json)

# Check which node is the leader
curl -s http://localhost:8210/v1/sys/leader \
  -H "X-Vault-Token: $ROOT_TOKEN" | jq '{ha_enabled, is_self, leader_address}'

# List all Raft peers with their roles
curl -s http://localhost:8210/v1/sys/storage/raft/configuration \
  -H "X-Vault-Token: $ROOT_TOKEN" | jq '.data.config.servers[] | {node_id, address, leader, voter}'
```

Expected output:
```json
{ "node_id": "vault-1", "address": "vault-node-1:8201", "leader": true,  "voter": true }
{ "node_id": "vault-2", "address": "vault-node-2:8201", "leader": false, "voter": true }
{ "node_id": "vault-3", "address": "vault-node-3:8201", "leader": false, "voter": true }
```

HTTP status codes from the health endpoint:
- `200` → active leader
- `429` → standby follower (healthy)
- `503` → sealed or unhealthy

---

## 15.8 Test Replication

```bash
ROOT_TOKEN=$(jq -r '.root_token' vault-ha-init.json)

# Enable KV v2
curl -s -X POST http://localhost:8210/v1/sys/mounts/secret \
  -H "X-Vault-Token: $ROOT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"type": "kv", "options": {"version": "2"}}'

# Write a secret to the leader (node-1)
curl -s -X POST http://localhost:8210/v1/secret/data/test-ha \
  -H "X-Vault-Token: $ROOT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"data": {"cluster": "raft-ha", "level": "15"}}'

# Read from follower node-2 — must return the same data
curl -s http://localhost:8220/v1/secret/data/test-ha \
  -H "X-Vault-Token: $ROOT_TOKEN" | jq '.data.data'

# Read from follower node-3 — must return the same data
curl -s http://localhost:8230/v1/secret/data/test-ha \
  -H "X-Vault-Token: $ROOT_TOKEN" | jq '.data.data'
```

Both followers must return:
```json
{ "cluster": "raft-ha", "level": "15" }
```

---

## 15.9 Test Failover

```bash
ROOT_TOKEN=$(jq -r '.root_token' vault-ha-init.json)

# Kill the current leader (node-1)
docker stop vault-node-1
sleep 5

# node-2 or node-3 becomes the new leader — check
curl -s http://localhost:8220/v1/sys/leader \
  -H "X-Vault-Token: $ROOT_TOKEN" | jq '{is_self, leader_address}'

# Write to the new leader — cluster must still accept writes
curl -s -X POST http://localhost:8220/v1/secret/data/failover-test \
  -H "X-Vault-Token: $ROOT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"data": {"failover": "success"}}' | jq

# Restart node-1 and unseal it — rejoins as follower
KEY1=$(jq -r '.keys_base64[0]' vault-ha-init.json)
KEY2=$(jq -r '.keys_base64[1]' vault-ha-init.json)
KEY3=$(jq -r '.keys_base64[2]' vault-ha-init.json)

docker start vault-node-1
sleep 3
for KEY in "$KEY1" "$KEY2" "$KEY3"; do
  curl -s -X POST http://localhost:8210/v1/sys/unseal \
    -H "Content-Type: application/json" \
    -d "{\"key\": \"$KEY\"}" | jq '{sealed, progress}'
done

# Verify node-1 is back as follower and has synced data
sleep 3
curl -s http://localhost:8210/v1/secret/data/failover-test \
  -H "X-Vault-Token: $ROOT_TOKEN" | jq '.data.data'
```

---

## 15.10 Reset (Fresh Start)

Use this if the cluster is in a broken state and needs to be rebuilt from scratch.

> **Warning:** This deletes all data permanently. Secrets cannot be recovered.

```bash
cd docs/level15-ha-raft-persistence

# Stop and remove containers
docker compose down

# Delete all vault data
sudo rm -rf data/vault-1/* data/vault-2/* data/vault-3/*

# Reset permissions
chmod 777 data/vault-1 data/vault-2 data/vault-3

# Start fresh — then follow sections 15.3 → 15.5 again
docker compose up -d
```

---

## 15.11 Unseal After Restart

Every time the containers restart (crash, `docker compose down/up`), all nodes come up sealed.
Run this to unseal after any restart:

```bash
cd docs/level15-ha-raft-persistence

KEY1=$(jq -r '.keys_base64[0]' vault-ha-init.json)
KEY2=$(jq -r '.keys_base64[1]' vault-ha-init.json)
KEY3=$(jq -r '.keys_base64[2]' vault-ha-init.json)

for PORT in 8210 8220 8230; do
  echo "=== Unsealing port $PORT ==="
  for KEY in "$KEY1" "$KEY2" "$KEY3"; do
    curl -s -X POST http://localhost:$PORT/v1/sys/unseal \
      -H "Content-Type: application/json" \
      -d "{\"key\": \"$KEY\"}" | jq '{sealed, progress, t}'
  done
done
```

> After an ordinary restart (not a fresh init), all nodes already know each other —
> you can unseal all 3 in parallel without waiting. The wait in section 15.5 is
> only needed on first init.

---

## API Reference

| Operation | Method | Path |
|---|---|---|
| Initialize | POST | `/v1/sys/init` |
| Unseal | POST | `/v1/sys/unseal` |
| Seal | POST | `/v1/sys/seal` |
| Health check | GET | `/v1/sys/health` |
| Token lookup | GET | `/v1/auth/token/lookup-self` |
| Leader status | GET | `/v1/sys/leader` |
| Raft peers | GET | `/v1/sys/storage/raft/configuration` |
| Remove peer | POST | `/v1/sys/storage/raft/remove-peer` |
| Snapshot (backup) | GET | `/v1/sys/storage/raft/snapshot` |
| Restore snapshot | POST | `/v1/sys/storage/raft/snapshot-force` |
