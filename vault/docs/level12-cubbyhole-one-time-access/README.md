# Level 12 — Cubbyhole & One-Time Access

### Requirements:
  - **Vault Service is Running** from level 0
  - **Vault Address:** `https://vault.lab.mecan.ir`
  - **Auth:** Root token `myroot` (dev mode only)
  - **Tools:** install `jq` command
  - **ROLE_ID** and **SECRET_ID** from level 3

---

## Overview

Cubbyhole is Vault's **per-token private storage**. Unlike KV secrets which are
shared, cubbyhole data belongs exclusively to one token. No other token —
not even root — can read another token's cubbyhole.

When the token is revoked or expires, its cubbyhole is permanently destroyed.

```
Token A ──> cubbyhole/secret  <─── only Token A can read/write this
Token B ──> cubbyhole/secret  <─── completely separate namespace (Token B's own)
root    ──> cubbyhole/secret  <─── sees root's own cubbyhole (empty)
```

---

## 12.1 Cubbyhole Basics

Cubbyhole is always enabled at `/cubbyhole/`. No setup required.

### Write to your cubbyhole

```bash
# get MY_TOKEN via AppRole login (ROLE_ID and SECRET_ID from level 3)
MY_TOKEN=$(curl -s -X POST https://vault.lab.mecan.ir/v1/auth/approle/login \
  -H "Content-Type: application/json" \
  -d "{\"role_id\": \"$ROLE_ID\", \"secret_id\": \"$SECRET_ID\"}" \
  | jq -r '.auth.client_token')

echo $MY_TOKEN
```

```bash
curl -X POST https://vault.lab.mecan.ir/v1/cubbyhole/my-secret \
  -H "X-Vault-Token: $MY_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"api_key": "sk-prod-ultra-secret", "env": "production"}'
```

### Read from your cubbyhole

```bash
curl https://vault.lab.mecan.ir/v1/cubbyhole/my-secret \
  -H "X-Vault-Token: $MY_TOKEN"
```

### Isolation: another token reads the same path

A different token reading `cubbyhole/my-secret` sees **its own** empty cubbyhole:

```json
{"errors": []}
```

The path is identical but the namespace is the token — there is no collision.

---

## 12.2 Token Revocation Destroys the Cubbyhole

```bash
# Revoke the token
curl -X POST https://vault.lab.mecan.ir/v1/auth/token/revoke \
  -H "X-Vault-Token: myroot" \
  -H "Content-Type: application/json" \
  -d "{\"token\": \"$MY_TOKEN\"}"

# Any access with the revoked token:
# Error: permission denied — invalid token
```

The cubbyhole and all its contents are permanently gone.

---

## 12.3 One-Time Access: `num_uses` Token

Vault tokens support `num_uses` — a counter that decrements on every request.
When it reaches 0, the token is automatically revoked.

Combine this with cubbyhole for **true one-time secret delivery**:

```bash
# Admin creates a 2-use bootstrap token
curl -X POST https://vault.lab.mecan.ir/v1/auth/token/create \
  -H "X-Vault-Token: myroot" \
  -H "Content-Type: application/json" \
  -d '{
    "ttl": "5m",
    "num_uses": 2,
    "display_name": "new-service-bootstrap",
    "policies": ["default"]
  }' | jq
```

With `num_uses: 2`:
- **Use 1** → Admin writes credentials to cubbyhole
- **Use 2** → Service reads credentials from cubbyhole
- **Use 3** → `permission denied — invalid token`

---

## 12.4 Bootstrap Pattern: Secure AppRole Delivery

### Scenario
A new service is being deployed. It needs its `role_id` and `secret_id` to
authenticate with Vault via AppRole. How do you securely deliver `secret_id`
without hardcoding it?

**Without cubbyhole:** `secret_id` travels in plaintext through CI/CD env vars,
logs, or config files — any of which can be leaked.

**With cubbyhole + num_uses token:**

```
Step 1: Admin generates bootstrap token (num_uses=2, TTL=5m)
Step 2: Admin writes secret_id into bootstrap token's cubbyhole  [use #1]
Step 3: Admin sends only the bootstrap token to the service (e.g. via env var)
Step 4: Service reads cubbyhole to get secret_id                 [use #2]
Step 5: Service calls AppRole login with role_id + secret_id → gets real token
Step 6: Bootstrap token is now dead — secret_id is gone from cubbyhole
```

```bash
# Step 1+2: Admin
SECRET_ID=$(curl -s -X POST https://vault.lab.mecan.ir/v1/auth/approle/role/backend-service/secret-id \
  -H "X-Vault-Token: myroot" \
  | jq -r '.data.secret_id')

BOOTSTRAP=$(curl -s -X POST https://vault.lab.mecan.ir/v1/auth/token/create \
  -H "X-Vault-Token: myroot" \
  -H "Content-Type: application/json" \
  -d '{"ttl":"5m","num_uses":2,"policies":["default"]}' \
  | jq -r '.auth.client_token')

curl -X POST https://vault.lab.mecan.ir/v1/cubbyhole/init \
  -H "X-Vault-Token: $BOOTSTRAP" \
  -H "Content-Type: application/json" \
  -d "{\"role_id\": \"$ROLE_ID\", \"secret_id\": \"$SECRET_ID\"}"
# → use #1 consumed

# Step 3: pass $BOOTSTRAP to the service via secure channel (not secret_id itself)

# Step 4: Service reads cubbyhole
CREDS=$(curl -s https://vault.lab.mecan.ir/v1/cubbyhole/init \
  -H "X-Vault-Token: $BOOTSTRAP")
echo $CREDS | jq
# → use #2 consumed, bootstrap token now dead

# Step 5: Service logs in with AppRole
curl -X POST https://vault.lab.mecan.ir/v1/auth/approle/login \
  -H "Content-Type: application/json" \
  -d "{\"role_id\": \"$(echo $CREDS | jq -r '.data.role_id')\", \"secret_id\": \"$(echo $CREDS | jq -r '.data.secret_id')\"}"
# → gets real policy-scoped token, valid for hours
```

---

## 12.5 Test Results

| Test                                              | Result |
|---------------------------------------------------|--------|
| Token writes to cubbyhole                         | ✅     |
| Same token reads its own cubbyhole                | ✅     |
| Different token reads same path — sees its own (empty) | ✅ |
| Root token reads another token's cubbyhole — sees root's (empty) | ✅ |
| Token revoked — cubbyhole permanently destroyed   | ✅     |
| `num_uses: 2` token exhausted after 2 uses        | ✅     |

---

## Cubbyhole vs KV Secrets

| Property          | Cubbyhole                         | KV Secrets                        |
|-------------------|-----------------------------------|-----------------------------------|
| Scope             | Per-token — private               | Shared — any authorized token     |
| Lifetime          | Tied to token — auto-destroyed    | Independent — persists until deleted |
| Root can read     | No                                | Yes (with policy)                 |
| Use case          | Bootstrap, one-time delivery      | Long-lived shared configuration   |
| Audit trail       | Yes                               | Yes                               |

---

## API Reference

| Operation              | Method | Path                          |
|------------------------|--------|-------------------------------|
| Write to cubbyhole     | POST   | `/v1/cubbyhole/<path>`        |
| Read from cubbyhole    | GET    | `/v1/cubbyhole/<path>`        |
| List cubbyhole         | LIST   | `/v1/cubbyhole/`              |
| Delete from cubbyhole  | DELETE | `/v1/cubbyhole/<path>`        |
| Create num_uses token  | POST   | `/v1/auth/token/create` with `num_uses` field |
