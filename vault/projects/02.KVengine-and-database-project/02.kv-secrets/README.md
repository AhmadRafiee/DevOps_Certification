# Level 2 — KV Secrets: Storing and Retrieving Passwords

This level shows the full lifecycle of a secret:
a service needs a password → authenticates to Vault → receives a short-lived token → reads the secret.

---

## The Problem We're Solving

Without Vault, services get credentials one of these bad ways:

| Method                        | Problem                                      |
|-------------------------------|----------------------------------------------|
| Hard-coded in source code     | Leaked via git history                       |
| `.env` file on the server     | Any process / developer with SSH can read it |
| Passed as env var at deploy   | Visible in `docker inspect`, CI logs         |
| Config stored in a DB table   | One DB breach exposes all credentials        |

**With Vault:** No service ever holds a credential permanently.
Each service authenticates, receives a token valid for 1 hour, and reads only the secrets it's allowed to read.

---

## Architecture of This Scenario

```
                          ┌─────────────────────────────────────┐
                          │            HashiCorp Vault          │
  app-service ──(1)──►    │                                     │
     AppRole login        │  KV v2 Secrets Engine               │
          │               │  ┌──────────────────────────────┐   │
          │◄──(2)── token │  │ secret/database/postgres     │   │
          │               │  │ secret/services/redis        │   │
          └──(3)──►       │  │ secret/services/api-gateway  │   │
        read secret       │  └──────────────────────────────┘   │
          │               │                                     │
          │◄──(4)── data  │  AppRole Auth    Policies           │
                          │  ┌───────────┐   ┌──────────────┐   │
  api-gateway ────────►   │  │app-service│   │app-service-  │   │
    (same flow,           │  │api-gateway│   │policy        │   │
     different role)      │  └───────────┘   │api-gateway-  │   │
                          │                  │policy        │   │
                          │                  └──────────────┘   │
                          └─────────────────────────────────────┘
```

---

## Secrets Stored

| Path                            | Fields                          | Who Can Read         |
|---------------------------------|---------------------------------|----------------------|
| `secret/database/postgres`      | `username`, `password`          | `app-service`        |
| `secret/services/redis`         | `password`                      | `app-service`        |
| `secret/services/api-gateway`   | `api_key`                       | `api-gateway`        |

---

## Auth Flow: AppRole

AppRole is the standard auth method for machine-to-machine authentication.

```
         Deploy pipeline                Service container
              │                               │
              │  vault write                  │
              │  auth/approle/role/           │
              │  app-service/secret-id        │
              │                               │
              │──── VAULT_ROLE_ID ───────────►│  (static, stored in config)
              │──── VAULT_SECRET_ID ─────────►│  (one-time, injected at startup)
                                              │
                                              │  POST /v1/auth/approle/login
                                              │──────────────────────────────►│ Vault
                                              │◄────── client_token (1h TTL) ─│
                                              │
                                              │  GET /v1/secret/data/database/postgres
                                              │  X-Vault-Token: <client_token>
                                              │──────────────────────────────►│ Vault
                                              │◄────── { username, password } ─│
                                              │
                                              │  (token expires — secret gone from memory)
```

**Why two IDs?**

| ID            | Analogy     | Characteristic                              |
|---------------|-------------|---------------------------------------------|
| `role_id`     | Username    | Static, not secret, stored in app config    |
| `secret_id`   | Password    | Single-use (or limited TTL), injected fresh |

A stolen `role_id` alone is useless without the `secret_id`.

---

## Policies: What Each Service Can Access

### `app-service-policy`

```hcl
path "secret/data/database/postgres" {
  capabilities = ["read"]
}

path "secret/data/services/redis" {
  capabilities = ["read"]
}
```

`app-service` can **only read** those two paths. It cannot list, create, update, or delete.
It cannot see `secret/services/api-gateway` at all — even its existence.

### `api-gateway-policy`

```hcl
path "secret/data/services/api-gateway" {
  capabilities = ["read"]
}
```

`api-gateway` is completely isolated — it sees only its own secret.

---

## Quickstart

### Prerequisites

Vault must be running from `01.setup/`:

```bash
cd ../01.setup
docker compose up -d
```

### Step 1: Initialize Vault

```bash
./init-vault.sh
```

This script:
1. Enables KV v2 at `secret/`
2. Writes the three secrets
3. Creates both policies
4. Enables AppRole and creates two roles
5. Prints RoleID + SecretID for each service

Output example:
```
==> Checking Vault is reachable...
    Vault is up.

==> Enabling KV v2 secrets engine at 'secret/'...
==> Writing secrets...
    secret/database/postgres  ✓
    secret/services/redis     ✓
    secret/services/api-gateway ✓
==> Writing policies...
    app-service-policy  ✓
    api-gateway-policy  ✓
==> Enabling AppRole auth method...
    role/app-service    ✓
    role/api-gateway    ✓

==> AppRole credentials for services
  [app-service]
    VAULT_ROLE_ID   = xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    VAULT_SECRET_ID = yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy

  [api-gateway]
    VAULT_ROLE_ID   = aaaaaaaa-...
    VAULT_SECRET_ID = bbbbbbbb-...
```

### Step 2: Simulate a Service Retrieving a Secret

```bash
./get-secret.sh <role_id> <secret_id> secret/database/postgres
```

Output:
```
==> Step 1: Authenticate with AppRole → get a short-lived token
    Token obtained (TTL: 3600s)

==> Step 2: Read secret at 'secret/database/postgres'

    Raw response:
    {
        "data": {
            "data": {
                "password": "S3cur3_DB_P@ss!",
                "username": "app_user"
            },
            "metadata": { "version": 1, ... }
        }
        ...
    }

==> Step 3: Extract individual fields
    username = app_user
    password = S3cur3_DB_P@ss!

==> Done. The service now holds the secret in memory — never written to disk.
```

### Step 3: Verify Isolation (api-gateway cannot read postgres)

```bash
# Get api-gateway credentials from init-vault.sh output, then:
./get-secret.sh <gw_role_id> <gw_secret_id> secret/database/postgres
```

Vault returns **403 Forbidden** — the policy blocks it.

---

## KV v2: Path Convention

KV v2 separates the **data plane** from the **metadata plane**:

| What you want       | API path                         | CLI command                     |
|---------------------|----------------------------------|---------------------------------|
| Read current value  | `GET /v1/secret/data/<path>`     | `vault kv get secret/<path>`    |
| Read version N      | `GET /v1/secret/data/<path>?version=N` | `vault kv get -version=N secret/<path>` |
| List all keys       | `LIST /v1/secret/metadata/<path>`| `vault kv list secret/<path>`   |
| Delete a secret     | `DELETE /v1/secret/data/<path>`  | `vault kv delete secret/<path>` |
| See version history | `GET /v1/secret/metadata/<path>` | `vault kv metadata get secret/<path>` |

**In policies**, you must write `secret/data/...` not `secret/...` — the `/data/` prefix
is part of the actual path KV v2 uses internally.

---

## Useful Vault CLI Commands

```bash
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=myroot

# Read a secret
vault kv get secret/database/postgres

# See version history
vault kv metadata get secret/database/postgres

# Update a secret (creates version 2)
vault kv put secret/database/postgres username="app_user" password="NewPass!"

# Roll back to version 1
vault kv rollback -version=1 secret/database/postgres

# Check what a token is allowed to do
vault token lookup <token>

# Verify policy
vault policy read app-service-policy
```

---

## Key Concepts Introduced in This Level

| Concept         | Description                                                                 |
|-----------------|-----------------------------------------------------------------------------|
| **KV v2**       | Key-Value secrets engine with versioning and metadata                       |
| **Policy**      | HCL rules mapping paths to capabilities (`read`, `write`, `list`, `delete`) |
| **AppRole**     | Auth method for services: role_id (static) + secret_id (dynamic)            |
| **Token TTL**   | Tokens expire automatically — secrets don't outlive their authorization     |
| **Isolation**   | Each service's token is scoped to exactly what it needs — nothing more      |
