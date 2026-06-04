# HashiCorp Vault — Learning Lab

A hands-on, step-by-step lab for learning Vault secrets management.
Each level builds on the previous one — start from `01.setup` and work forward.

---

## Why Vault?

Applications need passwords, API keys, and certificates to function.
The naive approach — config files, environment variables, hardcoded values — creates a
**secrets sprawl** problem: credentials end up in git history, CI logs, and docker inspect output.

Vault centralizes all secrets behind an authenticated API:

- Services never hold a credential longer than needed
- Every read is logged with who, what, and when
- Rotating a password means updating one place — not redeploying every service
- A compromised service token is scoped to exactly what that service needs, nothing more

---

## Lab Structure

```
vault/
├── 01.setup/              ← Run Vault with Docker Compose
│   ├── compose.yml
│   ├── kind-vault-lab.yaml
│   └── README.md
│
├── 02.kv-secrets/         ← Store passwords; services retrieve them via AppRole
│   ├── init-vault.sh
│   ├── get-secret.sh
│   └── README.md
│
├── 03.multi-service/      ← 6 services, ~20 credentials: dynamic DB + static KV
│   ├── compose.yml
│   ├── init-vault.sh
│   ├── get-db-creds.sh
│   ├── get-static-secret.sh
│   └── README.md
│
└── README.md              ← this file
```

---

## Levels

| Level | Directory          | What You Learn                                                          |
|-------|--------------------|-------------------------------------------------------------------------|
| 01    | `01.setup/`        | Run Vault in dev mode; understand sealed/unsealed state                 |
| 02    | `02.kv-secrets/`   | KV v2 engine, policies, AppRole auth, secret retrieval                  |
| 03    | `03.multi-service/`| Database engine (dynamic creds), two-engine pattern, service isolation  |

---

## Quickstart

```bash
# 1. Start Vault
cd 01.setup
docker compose up -d

# 2. Verify it's running
curl http://127.0.0.1:8200/v1/sys/health | python3 -m json.tool

# 3. KV secrets + AppRole (single service)
cd ../02.kv-secrets
./init-vault.sh
./get-secret.sh <role_id> <secret_id> secret/database/postgres

# 4. Multi-service: dynamic DB credentials + static secrets
cd ../03.multi-service
docker compose up -d        # starts Postgres
./init-vault.sh
./get-db-creds.sh     <role_id> <secret_id> user-service-role
./get-static-secret.sh <role_id> <secret_id> secret/services/payment/stripe
```

---

## Core Concepts

| Term           | One-line definition                                                     |
|----------------|-------------------------------------------------------------------------|
| **Secret**     | Any sensitive key-value pair: password, token, certificate              |
| **Engine**     | A plugin that provides a feature — KV, PKI, Database, Transit, etc.    |
| **Policy**     | HCL rules that map paths to allowed operations (read, write, list…)    |
| **Token**      | The credential used for every API call — has a TTL and attached policies|
| **AppRole**    | Auth method for services: static RoleID + dynamic SecretID → token     |
| **Lease**      | A time-bound grant — Vault revokes it automatically when it expires     |
| **Seal/Unseal**| Vault's lock state — a sealed Vault rejects all requests               |

---

## Dev Mode vs Production

This lab runs Vault in **dev mode** — convenient for learning, not for production.

| Aspect          | Dev Mode                        | Production Mode                        |
|-----------------|---------------------------------|----------------------------------------|
| Storage         | In-memory (lost on restart)     | Persistent (Raft, Consul, etc.)        |
| Seal state      | Always unsealed                 | Starts sealed; requires unseal keys    |
| TLS             | Disabled on internal listener   | Required                               |
| Root token      | Fixed (`myroot`)                | Generated once, then revoked           |
| Use case        | Learning and local development  | Any real workload                      |
