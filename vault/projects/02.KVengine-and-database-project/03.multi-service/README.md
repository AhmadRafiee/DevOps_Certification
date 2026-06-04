# Level 03 — Multi-Service Secrets: Dynamic + Static Credentials

This level brings up 6 services that collectively need ~20 credentials.
It uses two Vault engines together: **Database** (dynamic) and **KV v2** (static).

---

## The Two-Engine Model

Not all credentials are equal. Vault handles them differently:

| Credential type          | Engine          | How it works                                                  |
|--------------------------|-----------------|---------------------------------------------------------------|
| Database user/password   | Database engine | Vault generates a real Postgres user on demand with a TTL — auto-revoked on expiry |
| API keys, shared tokens  | KV v2           | You write them once; services read them via their token        |

**Why dynamic DB credentials?**
A static DB password is a single point of failure — if one service is compromised,
the attacker has a permanent credential. A dynamic credential with a 1-hour TTL is
automatically invalidated, and every credential is unique per service per request.

---

## Services and Their Credentials

```
api-gateway
  └── KV: shared/jwt            (jwt secret + algorithm)
  └── KV: services/api-gateway  (admin token, dashboard password)

user-service
  ├── DB: user-service-role     (dynamic Postgres user, TTL 1h)
  └── KV: shared/redis          (redis password)

order-service
  ├── DB: order-service-role    (dynamic Postgres user, TTL 1h)
  ├── KV: shared/redis
  └── KV: shared/rabbitmq       (username + password)

payment-service
  ├── DB: payment-service-role  (dynamic Postgres user, TTL 30m)
  └── KV: services/payment/stripe  (api_key + webhook_secret)

notification-service
  ├── KV: services/notification/sendgrid  (api_key, from_email)
  ├── KV: services/notification/smtp      (host, port, user, pass)
  └── KV: shared/rabbitmq

search-service
  └── KV: services/search/elasticsearch  (url, api_key, index_prefix)
```

Total: **8 KV paths** (15 individual fields) + **3 dynamic DB roles** = ~20 credentials

---

## Architecture

```
                    ┌──────────────────────────────────────────────────┐
                    │                HashiCorp Vault                   │
                    │                                                  │
  api-gateway ─────►│  AppRole login → token                          │
  user-service ────►│     │                                           │
  order-service ───►│     ▼                                           │
  payment-service ─►│  ┌──────────────────┐  ┌───────────────────┐   │
  notification ────►│  │  KV v2 engine    │  │  Database engine  │   │
  search-service ──►│  │  secret/...      │  │  database/creds/  │   │
                    │  │  static secrets  │  │  → Postgres       │───┼──► Postgres
                    │  └──────────────────┘  └───────────────────┘   │    CREATE/DROP
                    │                                                  │    users
                    └──────────────────────────────────────────────────┘
```

---

## Quickstart

### 1. Start Vault (if not already running)

```bash
cd ../01.setup
docker compose up -d
```

### 2. Start Postgres

```bash
cd 03.multi-service
docker compose up -d
```

### 3. Initialize Vault

```bash
chmod +x init-vault.sh get-db-creds.sh get-static-secret.sh
./init-vault.sh
```

The script outputs a RoleID + SecretID for each service. Copy them.

### 4. Test — Dynamic DB credentials (user-service)

```bash
./get-db-creds.sh <role_id> <secret_id> user-service-role
```

Expected output:
```
==> Step 1: AppRole login → short-lived Vault token
    Token acquired (TTL: 3600s)

==> Step 2: Request dynamic Postgres credentials for role 'user-service-role'

    username  = v-approle-user-servi-AbCdEfGhIj
    password  = A1b2C3d4-xxxx-yyyy
    lease_id  = database/creds/user-service-role/xxxx
    lease_ttl = 3600s

==> This user now exists in Postgres. Vault will DROP it when the lease expires.
```

### 5. Test — Static secret (payment-service)

```bash
./get-static-secret.sh <role_id> <secret_id> secret/services/payment/stripe
```

### 6. Test Isolation

Use `user-service` credentials to request `secret/services/payment/stripe`:
```bash
./get-static-secret.sh <user_service_role_id> <user_service_secret_id> secret/services/payment/stripe
```

Vault returns **403** — `user-service-policy` has no access to the payment path.

---

## Dynamic Credentials: Lifecycle

```
Service starts
     │
     ▼
AppRole login ──────────────────────────► Vault issues token (TTL 1h)
     │
     ▼
GET /v1/database/creds/user-service-role ► Vault runs:
     │                                       CREATE ROLE "v-approle-xxx"
     │                                       WITH LOGIN PASSWORD 'yyy'
     │                                       VALID UNTIL '2026-06-04 11:00';
     │
     ▼
Service connects to Postgres with v-approle-xxx / yyy
     │
     ▼  (1 hour later)
Vault automatically runs:
     DROP ROLE "v-approle-xxx"             ← credential is gone, connection severed
```

If the service needs to keep running beyond 1h it calls **renew lease** before expiry.
If the service crashes, the credential disappears on its own after the TTL.

---

## Useful API Calls

```bash
export VAULT_ADDR=http://127.0.0.1:8200
export H="X-Vault-Token: myroot"

# List all KV secrets under services/
curl -s --request LIST -H "$H" $VAULT_ADDR/v1/secret/metadata/services | python3 -m json.tool

# Check active leases for a DB role
curl -s --request LIST -H "$H" $VAULT_ADDR/v1/sys/leases/lookup/database/creds/user-service-role | python3 -m json.tool

# Manually revoke a lease early
curl -s --request PUT -H "$H" -H "Content-Type: application/json" \
  --data '{"lease_id":"database/creds/user-service-role/xxxx"}' \
  $VAULT_ADDR/v1/sys/leases/revoke

# Read a policy
curl -s -H "$H" $VAULT_ADDR/v1/sys/policies/acl/payment-service-policy | python3 -m json.tool
```

---

## Key Concepts in This Level

| Concept                  | Description                                                                 |
|--------------------------|-----------------------------------------------------------------------------|
| **Database engine**      | Vault connects to Postgres and generates real users on demand               |
| **creation_statements**  | SQL template Vault uses to create each dynamic user                         |
| **Lease**                | A time-bound grant — Vault auto-revokes when expired                        |
| **Lease renewal**        | A service can extend its credential before it expires                       |
| **Policy scoping**       | Each service token is limited to exactly its own paths — zero cross-access  |
| **Two-engine pattern**   | Dynamic for DB (short-lived, unique), static KV for external API keys       |
