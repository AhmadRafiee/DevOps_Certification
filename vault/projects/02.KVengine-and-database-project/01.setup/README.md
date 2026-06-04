# Level 0 — Setup: Running Vault with Docker Compose

**Vault Address:** `https://vault.lab.mecan.ir`

---

## What is HashiCorp Vault?

Vault is a secrets management tool. It stores, controls access to, and audits
sensitive data — passwords, API keys, certificates, and encryption keys.

Core problems it solves:

| Problem                          | Without Vault              | With Vault                        |
|----------------------------------|----------------------------|-----------------------------------|
| DB passwords in config files     | Plaintext, version-controlled | Fetched at runtime, never stored  |
| Shared credentials across teams  | One leaked password = breach  | Per-service tokens with TTL       |
| Certificate management           | Manual, error-prone           | Auto-issued, short-lived          |
| Encryption keys in application   | Key leaks with the app        | Keys never leave Vault            |
| Audit trail                      | None                          | Every request logged and hashed   |

---

## Architecture

```
                ┌─────────────────────────────┐
                │         Vault Server        │
                │                             │
  Client ──────►│  Auth    Secrets    Audit   │
  (curl/app)    │  Engine  Engines    Device  │
                │                             │
                │  Storage Backend (in-memory │
                │  in dev mode, Raft in prod) │
                └─────────────────────────────┘
```

In **dev mode** (used here):
- Vault starts pre-initialized and unsealed
- Data is stored in memory — lost on container restart
- Root token is fixed and known
- TLS is disabled on the internal listener

In **production mode**:
- Vault starts sealed — requires unseal keys to start
- Data persists to a storage backend (Raft, Consul, etc.)
- TLS required
- Root token is generated once and should be revoked after initial setup

---

## Project Structure

```
vault/
├── compose.yml          ← Vault Services
└── docs/
    ├── level0-setup.md  ← this file
    ├── level1-kv-secrets.md
    └── ...
```

---

## compose.yml

```yaml
version: '3.8'

networks:
  infra-network:
    driver: bridge

volumes:
  vault-logs:       # audit log volume — mounted into Vault container

services:
  vault:
    image: hashicorp/vault:2.0
    container_name: hashicorp_vault
    networks:
      - infra-network
    ports:
      - "8200:8200"
    environment:
      VAULT_DEV_ROOT_TOKEN_ID: "myroot"       # fixed root token for dev
      VAULT_DEV_LISTEN_ADDRESS: "0.0.0.0:8200"
    volumes:
      - vault-logs:/vault/logs
    cap_add:
      - IPC_LOCK   # prevents memory from being swapped to disk

```

**`IPC_LOCK`** is a Linux capability that lets Vault lock memory pages to prevent
secrets from being swapped to disk. Always include it.

---

## Starting the Stack

```bash
cd docs/level00-setup

# Start both services
docker compose up -d

# Wait for Postgres to be ready
docker compose ps

# Follow Vault logs
docker compose logs -f vault
```

Expected Vault output on startup:
```
==> Vault server configuration:

             Api Address: http://0.0.0.0:8200
                     Cgo: disabled
         Cluster Address: https://0.0.0.0:8201
   Environment Variables: ...

WARNING! dev mode is enabled! In this mode, Vault runs entirely in-memory
and starts unsealed with a single unseal key. The root token is already
authenticated to the CLI, so you can immediately begin using Vault.
```

---

## Verifying Vault is Running

```bash
curl https://vault.lab.mecan.ir/v1/sys/health | python3 -m json.tool
```

Response:
```json
{
  "initialized": true,
  "sealed": false,
  "standby": false,
  "version": "2.0.1",
  "cluster_name": "vault-cluster-...",
  "enterprise": false
}
```

| Field         | Expected value | Meaning                              |
|---------------|----------------|--------------------------------------|
| `initialized` | `true`         | Vault has been set up                |
| `sealed`      | `false`        | Vault is open and serving requests   |
| `standby`     | `false`        | This node is the active leader       |

---

## Authentication

All API calls require a token in the `X-Vault-Token` header.

```bash
# Test authentication with root token
curl https://vault.lab.mecan.ir/v1/auth/token/lookup-self \
  -H "X-Vault-Token: myroot"
```

---

## Key Concepts

| Term           | Meaning                                                              |
|----------------|----------------------------------------------------------------------|
| **Secret**     | Any sensitive key-value data stored in Vault                         |
| **Engine**     | A plugin that provides a feature (KV, PKI, Transit, Database, etc.)  |
| **Mount**      | A path where an engine is activated (`secret/`, `pki/`, etc.)        |
| **Policy**     | An HCL document defining what paths a token can access               |
| **Token**      | A credential used to authenticate API calls — has TTL and policies   |
| **Lease**      | A time-bound grant for a secret — can be renewed or revoked          |
| **Seal/Unseal**| Vault's lock state — sealed Vault refuses all requests               |

---

## Stopping and Cleaning Up

```bash
# Stop containers, keep volumes
docker compose down

# Stop and delete all data (volumes)
docker compose down -v
```

**Note:** In dev mode, Vault loses all state on container restart.
Any secrets, policies, and auth methods must be re-configured.
This is expected for development — in production use a persistent storage backend.

---

## What's Running on Each Port

| Port   | Service    | Purpose                        |
|--------|------------|--------------------------------|
| `8200` | Vault      | API and UI                     |
| `8201` | Vault      | Cluster communication (HA)     |

## Setup kubernetes cluster with kind
```bash
cat <<'EOF' > kind-vault-lab.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: vault-lab
nodes:
  - role: control-plane
  - role: worker
EOF

kind create cluster --config kind-vault-lab.yaml --image kindest/node:v1.29.2

docker network connect app_net vault-lab-control-plane
docker network connect app_net vault-lab-worker
docker network connect kind hashicorp_vault
```