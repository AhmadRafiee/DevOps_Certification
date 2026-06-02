# Level 3 — AppRole Authentication

### Requirements:
  - **Vault Service is Running** from level 0
  - **Vault Address:** `https://vault.lab.mecan.ir`
  - **Auth:** Root token `myroot` (dev mode only)
  - **Tools:** install `jq` command
  - **Secret from Level 1:** the secret at `secret/myapp/database` must exist (created in Level 1) — the READ test in 2.3 depends on it

---

## Overview

AppRole is Vault's standard authentication method for machines and services.
Instead of baking a static token into your app, the service authenticates with two pieces:

| Credential  | Analogy  | Who holds it                        |
|-------------|----------|-------------------------------------|
| `role_id`   | username | Baked into the app image or config  |
| `secret_id` | password | Injected at runtime by CI/CD/orchestrator |

The separation matters: neither piece alone is enough to log in. If your image
is leaked, `role_id` is useless without `secret_id`.

---

## 3.1 Enable AppRole

### Scenario
AppRole auth is not enabled by default. An admin enables it once per Vault instance.

```bash
curl -X POST https://vault.lab.mecan.ir/v1/sys/auth/approle \
  -H "X-Vault-Token: myroot" \
  -H "Content-Type: application/json" \
  -d '{"type": "approle"}'
```

check approle is enabled

```bash
curl -s -H "X-Vault-Token: myroot" \
  https://vault.lab.mecan.ir/v1/sys/auth | jq
```

![approle](../image/03-approle.png)

---

## 3.2 Create a Role

### Scenario
We have a backend service that needs read access to `myapp/*`. We create a named
role for it, attach the right policy, and set limits on the token and secret_id lifetime.

```bash
curl -X POST https://vault.lab.mecan.ir/v1/auth/approle/role/backend-service \
  -H "X-Vault-Token: myroot" \
  -H "Content-Type: application/json" \
  -d '{
    "policies": ["myapp-readonly"],
    "token_ttl": "1h",
    "token_max_ttl": "4h",
    "secret_id_ttl": "24h",
    "secret_id_num_uses": 5
  }'
```

Key options:

| Option              | What it controls                                         |
|---------------------|----------------------------------------------------------|
| `token_ttl`         | How long the issued token lives                          |
| `token_max_ttl`     | Hard ceiling — even after renewals                       |
| `secret_id_ttl`     | How long a generated secret_id is valid                  |
| `secret_id_num_uses`| How many logins one secret_id can be used for (0 = unlimited) |

---

## 3.3 Fetch Credentials

### Get the Role ID (done once, ship with the app)

Capture the `role_id` straight into a shell variable with `jq`:

```bash
ROLE_ID=$(curl -s https://vault.lab.mecan.ir/v1/auth/approle/role/backend-service/role-id \
  -H "X-Vault-Token: myroot" | jq -r '.data.role_id')

echo "ROLE_ID=$ROLE_ID"
```

Response (what the API returns before extraction):
```json
{
  "data": {
    "role_id": "c1982591-1596-22b7-c2c7-d7297f2dd2b6"
  }
}
```

### Generate a Secret ID (done per-deploy by CI/CD)

```bash
SECRET_ID=$(curl -s -X POST https://vault.lab.mecan.ir/v1/auth/approle/role/backend-service/secret-id \
  -H "X-Vault-Token: myroot" | jq -r '.data.secret_id')

echo "SECRET_ID=$SECRET_ID"
```

Response (what the API returns before extraction):
```json
{
  "data": {
    "secret_id": "86a5a4d9-0570-2e7a-54ad-a6d3710f69ea",
    "secret_id_ttl": 86400,
    "secret_id_num_uses": 5
  }
}
```

---

## 3.4 Login (Service Side)

### Scenario
The service starts up. It has `role_id` from its config and `secret_id` injected
by the orchestrator. It calls Vault once to exchange them for a short-lived token,
then discards both credentials and only uses the token from here on.

Login with the `$ROLE_ID` and `$SECRET_ID` variables and capture the issued token:

```bash
VAULT_TOKEN=$(curl -s -X POST https://vault.lab.mecan.ir/v1/auth/approle/login \
  -H "Content-Type: application/json" \
  -d "{\"role_id\": \"$ROLE_ID\", \"secret_id\": \"$SECRET_ID\"}" \
  | jq -r '.auth.client_token')

echo "VAULT_TOKEN=$VAULT_TOKEN"
```

Response (what the API returns before extraction) — the service saves only `client_token`:
```json
{
  "auth": {
    "client_token": "hvs.XXXX",
    "policies": ["default", "myapp-readonly"],
    "lease_duration": 3600,
    "renewable": true
  }
}
```

### Read a secret using the AppRole token

No root token involved from this point forward — use the captured `$VAULT_TOKEN`:

```bash
curl -s https://vault.lab.mecan.ir/v1/secret/data/myapp/database \
  -H "X-Vault-Token: $VAULT_TOKEN" | jq
```

---

## 3.5 Secret ID Use Limits

### Scenario
Setting `secret_id_num_uses: 5` means the same secret_id can only authenticate
5 times. On the 6th attempt Vault rejects it — even if it hasn't expired by time.
This limits damage if a secret_id leaks: an attacker can only use it a finite
number of times, and you'll notice the app failing to start.

Result from live test:
- Uses 1–5: login succeeds
- Use 6: `invalid role or secret ID`

To generate a fresh secret_id for the next deploy:

```bash
curl -X POST https://vault.lab.mecan.ir/v1/auth/approle/role/backend-service/secret-id \
  -H "X-Vault-Token: myroot" | jq
```

---

## Full Flow Diagram

```
Admin (CI/CD)                    Service                        Vault
─────────────────────────────────────────────────────────────────────
                                                    ← create role
generate secret_id ────────────────────────────────────────────────→
                 ←──────────────────── secret_id ──────────────────
inject secret_id ──────────────────→
                                   login(role_id, secret_id) ─────→
                                   ←──────────────── token (1h) ───
                                   get secret(token) ─────────────→
                                   ←──────────── secret data ──────
                                   [discard role_id & secret_id]
                                   [use token until TTL, then renew]
```

---

## API Reference

| Operation          | Method | Path                                                    |
|--------------------|--------|---------------------------------------------------------|
| Enable AppRole     | POST   | `/v1/sys/auth/approle`                                  |
| Create role        | POST   | `/v1/auth/approle/role/<name>`                          |
| Read role          | GET    | `/v1/auth/approle/role/<name>`                          |
| Get role_id        | GET    | `/v1/auth/approle/role/<name>/role-id`                  |
| Generate secret_id | POST   | `/v1/auth/approle/role/<name>/secret-id`                |
| Login              | POST   | `/v1/auth/approle/login`                                |
