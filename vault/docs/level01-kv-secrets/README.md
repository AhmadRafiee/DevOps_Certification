# Level 1 — KV Secrets Engine

### Requirements:
  - **Vault Service is Running** from level 0
  - **Vault Address:** `https://vault.lab.mecan.ir`
  - **Auth:** Root token `myroot` (dev mode only)
  - **Tools:** install `jq` command
---

## 1.1 Write and Read a Secret

### Scenario
An application needs to securely store its database credentials somewhere outside the codebase. Instead of hardcoding them in config files or environment variables, the app reads them from Vault at runtime. We store the credentials once, and the app fetches them on demand.

### How it works
KV v2 (Key-Value version 2) is the simplest secrets engine. You write arbitrary JSON under a path, and Vault stores it encrypted. Every write creates a new **version** — old versions are retained automatically.

URL structure:
```
POST  /v1/secret/data/<path>   → write
GET   /v1/secret/data/<path>   → read
LIST  /v1/secret/metadata/<path> → list
```

### Write a secret

```bash
curl -X POST https://vault.lab.mecan.ir/v1/secret/data/myapp/database \
  -H "X-Vault-Token: myroot" \
  -H "Content-Type: application/json" \
  -d '{
    "data": {
      "host": "db.internal",
      "port": "5432",
      "username": "appuser",
      "password": "super-secret-pass"
    }
  }'
```

Response — Vault confirms the version created:
```json
{
  "data": {
    "created_time": "2026-05-31T14:27:01Z",
    "version": 1,
    "destroyed": false
  }
}
```

### Read a secret

```bash
curl https://vault.lab.mecan.ir/v1/secret/data/myapp/database \
  -H "X-Vault-Token: myroot" \
  | jq
```

Response — note the two nested `data` layers (outer = Vault metadata, inner = your data):
```json
{
  "data": {
    "data": {
      "host": "db.internal",
      "password": "super-secret-pass",
      "port": "5432",
      "username": "appuser"
    },
    "metadata": {
      "version": 1,
      "created_time": "2026-05-31T14:27:01Z"
    }
  }
}
```

---

## 1.2 Update and Versioning

### Scenario
The database password was rotated. We need to update the secret in Vault without losing the old value — because another service might still be using version 1 until it restarts. Vault keeps all versions so nothing breaks mid-rollout.

### Update the secret (creates a new version)

```bash
curl -X POST https://vault.lab.mecan.ir/v1/secret/data/myapp/database \
  -H "X-Vault-Token: myroot" \
  -H "Content-Type: application/json" \
  -d '{
    "data": {
      "host": "db.internal",
      "port": "5432",
      "username": "appuser",
      "password": "new-password-v2"
    }
  }'
```

### Read a specific version

```bash
# Read version 1 (old password)
curl "https://vault.lab.mecan.ir/v1/secret/data/myapp/database?version=1" \
  -H "X-Vault-Token: myroot" | jq 

# Read version 2 (current)
curl "https://vault.lab.mecan.ir/v1/secret/data/myapp/database?version=2" \
  -H "X-Vault-Token: myroot" | jq 
```

---

## 1.3 List and Delete

### Scenario
We need to audit what secrets exist under a given path, and then clean up secrets that are no longer needed. Vault provides soft-delete (recoverable) and hard-delete (permanent) for this purpose.

### List secrets under a path

```bash
curl -X LIST https://vault.lab.mecan.ir/v1/secret/metadata/myapp \
  -H "X-Vault-Token: myroot" | jq
```

Response:
```json
{
  "data": {
    "keys": ["database"]
  }
}
```

### Soft delete (recoverable)

Marks the latest version as deleted — data is still in Vault and can be undeleted.

```bash
curl -X DELETE https://vault.lab.mecan.ir/v1/secret/data/myapp/database \
  -H "X-Vault-Token: myroot"
```

### Undelete

```bash
curl -X POST https://vault.lab.mecan.ir/v1/secret/undelete/myapp/database \
  -H "X-Vault-Token: myroot" \
  -H "Content-Type: application/json" \
  -d '{"versions": [2]}'
```

### Hard delete / Destroy (permanent)

Data is cryptographically destroyed and cannot be recovered.

```bash
curl -X PUT https://vault.lab.mecan.ir/v1/secret/destroy/myapp/database \
  -H "X-Vault-Token: myroot" \
  -H "Content-Type: application/json" \
  -d '{"versions": [1, 2]}'
```

![history](../image/02.myapp-database.png)
---

## API Reference

| Operation     | Method | Path                              |
|---------------|--------|-----------------------------------|
| Write         | POST   | `/v1/secret/data/<path>`          |
| Read          | GET    | `/v1/secret/data/<path>`          |
| Read version  | GET    | `/v1/secret/data/<path>?version=N`|
| List          | LIST   | `/v1/secret/metadata/<path>`      |
| Soft delete   | DELETE | `/v1/secret/data/<path>`          |
| Undelete      | POST   | `/v1/secret/undelete/<path>`      |
| Hard destroy  | PUT    | `/v1/secret/destroy/<path>`       |
