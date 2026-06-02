# Level 7 — Dynamic Secrets: PostgreSQL

### Requirements:
  - **Vault Service is Running** from level 0
  - **Vault Address:** `https://vault.lab.mecan.ir`
  - **Auth:** Root token `myroot` (dev mode only)
  - **Tools:** install `jq` command

---

## Overview

With static secrets, you create a database user once and share its password across all services — if it leaks, every service is compromised.

With **dynamic secrets**, Vault creates a unique database user *on demand* for each request, with an expiration time baked in by PostgreSQL itself.
When the lease expires or is revoked, Vault drops the user from the database.

```
Service ──── request creds ──> Vault ──── CREATE ROLE ... ──> PostgreSQL
Service <─── username + pass ─── Vault
Service ──── connect ────────────────────────────────────────> PostgreSQL
[lease expires] ────────────── Vault ──── DROP ROLE ... ────> PostgreSQL
```

The service never sees a long-lived password. No rotation scripts needed.

---

## 7.1 Infrastructure Setup

Add PostgreSQL to `compose.yml` alongside Vault.
The `vaultadmin` user is the **admin account** Vault uses to create and drop dynamic users — it is never shared with application services.

```yaml
name: postgresql

networks:
  app_net:
    name: app_net
    external: true
  web_net:
    name: web_net
    external: true

volumes:
  postgres_data:
    name: postgres_data
    
services:
  postgres:
    image: postgres:16
    container_name: vault_postgres
    networks:
      - app_net
    environment:
      POSTGRES_DB: appdb
      POSTGRES_USER: vaultadmin
      POSTGRES_PASSWORD: vaultadmin-pass
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U vaultadmin -d appdb"]
      interval: 5s
      timeout: 5s
      retries: 10
```

```bash
cd level07-dynamic-secrets-db
docker compose up -d 
docker compose ps 
```

---

## 7.2 Enable Database Secrets Engine

```bash
curl -X POST https://vault.lab.mecan.ir/v1/sys/mounts/database \
  -H "X-Vault-Token: myroot" \
  -H "Content-Type: application/json" \
  -d '{"type": "database"}'
```

![database](../../image/07.database.png)

---

## 7.3 Configure the Database Connection

Vault stores the admin credentials and uses them internally.
The `{{username}}` and `{{password}}` placeholders are filled by Vault at connect time.

```bash
curl -X POST https://vault.lab.mecan.ir/v1/database/config/appdb \
  -H "X-Vault-Token: myroot" \
  -H "Content-Type: application/json" \
  -d '{
    "plugin_name": "postgresql-database-plugin",
    "connection_url": "postgresql://{{username}}:{{password}}@vault_postgres:5432/appdb?sslmode=disable",
    "allowed_roles": ["app-role", "readonly-role"],
    "username": "vaultadmin",
    "password": "vaultadmin-pass"
  }'
```

HTTP 204 = success (no response body).

![db-connection](../../image/07.db-connection.png)
---

## 7.4 Create Roles

A **role** defines the SQL template Vault runs when generating credentials.
The `{{name}}`, `{{password}}`, and `{{expiration}}` placeholders are filled
by Vault automatically.

### Read/write role (1h TTL)

```bash
curl -X POST https://vault.lab.mecan.ir/v1/database/roles/app-role \
  -H "X-Vault-Token: myroot" \
  -H "Content-Type: application/json" \
  -d '{
    "db_name": "appdb",
    "creation_statements": [
      "CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '\''{{password}}'\'' VALID UNTIL '\''{{expiration}}'\'';",
      "GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO \"{{name}}\";",
      "GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO \"{{name}}\";"
    ],
    "default_ttl": "1h",
    "max_ttl": "4h"
  }'
```

![db-role](../../image/07.db-role.png)

### Read-only role (30m TTL)

```bash
curl -X POST https://vault.lab.mecan.ir/v1/database/roles/readonly-role \
  -H "X-Vault-Token: myroot" \
  -H "Content-Type: application/json" \
  -d '{
    "db_name": "appdb",
    "creation_statements": [
      "CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '\''{{password}}'\'' VALID UNTIL '\''{{expiration}}'\'';",
      "GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";"
    ],
    "default_ttl": "30m",
    "max_ttl": "1h"
  }'
```

![db-read-only-role](../../image/07.db-reaed-only-role.png)

---

## 7.5 Generate Dynamic Credentials

### Scenario
A backend service starts up. It calls Vault once to get a temporary database
user. The user is unique to this service instance, expires in 1 hour, and
Vault will DROP it automatically.

```bash
curl https://vault.lab.mecan.ir/v1/database/creds/app-role \
  -H "X-Vault-Token: myroot" | jq
```

Response:
```json
{
  "lease_id": "database/creds/app-role/i9dWGCu3JYXnclTMHfqcOQeh",
  "lease_duration": 3600,
  "renewable": true,
  "data": {
    "username": "v-token-app-role-mdPFr3qIfvsWtZP9l92j-1780238621",
    "password": "o8s-xuR8tzT9Tvm1JGKL"
  }
}
```

The username format is `v-<auth_method>-<role>-<random>-<timestamp>`.
This makes it easy to identify in `pg_user` which Vault role issued each credential.

### Verify the user exists in PostgreSQL

First, log in to the PostgreSQL container as the admin user:

```bash
docker exec -it vault_postgres psql -U vaultadmin -d appdb
# password: vaultadmin-pass
```

Then query the dynamic users that Vault created:

```sql
SELECT usename, valuntil FROM pg_user WHERE usename LIKE 'v-token-%';

--                      usename                      |        valuntil
-- --------------------------------------------------+------------------------
--  v-token-app-role-mdPFr3qIfvsWtZP9l92j-1780238621 | 2026-05-31 15:43:46+00
--  v-token-readonly-ElEvT2C2QFlxETP03qAc-1780238621 | 2026-05-31 15:13:46+00
```

---

## 7.6 Renew a Lease

### Scenario
The service is long-running. It renews the credential lease before it expires
so the database user stays alive.

```bash
curl -X PUT https://vault.lab.mecan.ir/v1/sys/leases/renew \
  -H "X-Vault-Token: myroot" \
  -H "Content-Type: application/json" \
  -d '{
    "lease_id": "database/creds/app-role/i9dWGCu3JYXnclTMHfqcOQeh",
    "increment": 3600
  }'
```

Response:
```json
{
  "lease_id": "database/creds/app-role/i9dWGCu3JYXnclTMHfqcOQeh",
  "lease_duration": 3600,
  "renewable": true
}
```

---

## 7.7 Revoke a Lease

### Scenario
The service shuts down gracefully. It revokes its lease so Vault immediately
drops the database user — no waiting for TTL expiry.

```bash
curl -X PUT https://vault.lab.mecan.ir/v1/sys/leases/revoke \
  -H "X-Vault-Token: myroot" \
  -H "Content-Type: application/json" \
  -d '{"lease_id": "database/creds/app-role/i9dWGCu3JYXnclTMHfqcOQeh"}'
```

After revocation, the user is gone from PostgreSQL immediately:

```sql
SELECT usename FROM pg_user WHERE usename = 'v-token-app-role-...';
-- (0 rows)
```

---

## Comparison: Static vs Dynamic Credentials

| Property              | Static                        | Dynamic (Vault)                    |
|-----------------------|-------------------------------|-------------------------------------|
| Credential lifetime   | Forever until manually rotated| Minutes to hours, auto-expired      |
| Shared across services| Yes — one password for all    | No — unique per service instance    |
| Leak impact           | All services compromised      | One short-lived credential exposed  |
| Rotation              | Manual script or human effort | Automatic — Vault drops on expiry   |
| Audit trail           | Hard to trace who used what   | Every credential tied to a lease ID |

---

## API Reference

| Operation                  | Method | Path                                  |
|----------------------------|--------|---------------------------------------|
| Enable database engine     | POST   | `/v1/sys/mounts/database`             |
| Configure DB connection    | POST   | `/v1/database/config/<name>`          |
| Create role                | POST   | `/v1/database/roles/<role>`           |
| Generate credentials       | GET    | `/v1/database/creds/<role>`           |
| Renew lease                | PUT    | `/v1/sys/leases/renew`                |
| Revoke lease               | PUT    | `/v1/sys/leases/revoke`               |
| List leases                | LIST   | `/v1/sys/leases/lookup/database/creds/`|
