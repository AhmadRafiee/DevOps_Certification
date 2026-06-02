# Level 19 — Username/Password Authentication

### Requirements:
  - **Vault Service is Running** from level 15
  - **Vault Address:** `https://vault.lab.mecan.ir`
  - **Auth:** Root token `your-root-token-here` (dev mode only)
  - **Tools:** install `jq` command

---

## Overview

Userpass is Vault's built-in username/password auth method. Credentials are
stored and managed entirely inside Vault — no external LDAP or IdP needed.
It's best suited for human users in small teams or for simple lab setups.

```
User ──── POST /v1/auth/userpass/login/<username> with password ──→ Vault
Vault ──── verifies hash, issues token with configured policies ──→ User
```

---

## 19.1 Enable Userpass Auth

```bash
curl -X POST https://vault.lab.mecan.ir/v1/sys/auth/userpass \
  -H "X-Vault-Token: your-root-token-here" \
  -H "Content-Type: application/json" \
  -d '{"type": "userpass"}'
```

---

## 19.2 Create Users

```bash
curl -X POST https://vault.lab.mecan.ir/v1/auth/userpass/users/sara \
  -H "X-Vault-Token: your-root-token-here" \
  -H "Content-Type: application/json" \
  -d '{
    "password":      "sara-pass-123",
    "policies":      ["frontend-dev", "self-service"],
    "token_ttl":     "8h",
    "token_max_ttl": "24h"
  }'
```

Key fields:

| Field | Meaning |
|---|---|
| `password` | User's password — Vault stores the bcrypt hash |
| `policies` | Vault policies attached to the token on login |
| `token_ttl` | How long the issued token lives |
| `token_max_ttl` | Hard ceiling — even after renewals |

---

## 19.3 Login

```bash
curl -X POST https://vault.lab.mecan.ir/v1/auth/userpass/login/sara \
  -H "Content-Type: application/json" \
  -d '{"password": "sara-pass-123"}'
```

Response:
```json
{
  "auth": {
    "client_token": "hvs.XXXX",
    "policies": ["default", "frontend-dev", "self-service"],
    "lease_duration": 28800,
    "renewable": true
  }
}
```

---

## 19.4 Policies Used in This Lab

### `frontend-dev` — read only frontend secrets

```hcl
path "secret/data/team/frontend" {
  capabilities = ["read"]
}
path "secret/metadata/team/frontend" {
  capabilities = ["read"]
}
```

### `backend-dev` — read only backend secrets

```hcl
path "secret/data/team/backend" {
  capabilities = ["read"]
}
```

### `team-lead` — read all team secrets

```hcl
path "secret/data/team/*" {
  capabilities = ["read", "list"]
}
path "secret/metadata/team/*" {
  capabilities = ["read", "list"]
}
path "auth/userpass/users/*" {
  capabilities = ["read", "list"]
}
```

### `self-service` — users manage their own credentials

```hcl
path "auth/userpass/users/{{identity.entity.aliases.auth_userpass_0.name}}/password" {
  capabilities = ["update"]
}
path "auth/token/renew-self" {
  capabilities = ["update"]
}
path "auth/token/revoke-self" {
  capabilities = ["update"]
}
```

The `{{identity.entity.aliases...}}` template expands to the current user's
username automatically — users can only change their own password, not others'.

---

## 19.5 Admin Operations

### Read user info

```bash
curl https://vault.lab.mecan.ir/v1/auth/userpass/users/sara \
  -H "X-Vault-Token: your-root-token-here" | jq
```

Response:
```json
{
  "data": {
    "policies": ["frontend-dev", "self-service"],
    "token_ttl": 28800,
    "token_max_ttl": 86400
  }
}
```

### Update user policies or password

```bash
# Change password (admin)
curl -X POST https://vault.lab.mecan.ir/v1/auth/userpass/users/sara/password \
  -H "X-Vault-Token: your-root-token-here" \
  -d '{"password": "new-password"}'

# Update policies
curl -X POST https://vault.lab.mecan.ir/v1/auth/userpass/users/sara \
  -H "X-Vault-Token: your-root-token-here" \
  -d '{"policies": ["frontend-dev", "self-service", "extra-policy"]}'
```

### Delete (deactivate) user

```bash
curl -X DELETE https://vault.lab.mecan.ir/v1/auth/userpass/users/dani \
  -H "X-Vault-Token: your-root-token-here"
# HTTP 204 — user removed, existing tokens still valid until TTL
```

**Note:** Deleting a user does not revoke their existing tokens.
To immediately cut access, revoke their tokens explicitly:

```bash
# Look up tokens by accessor and revoke
curl -X POST https://vault.lab.mecan.ir/v1/auth/token/revoke-accessor \
  -H "X-Vault-Token: your-root-token-here" \
  -d '{"accessor": "<token_accessor>"}'
```

### List all users

```bash
curl -X LIST https://vault.lab.mecan.ir/v1/auth/userpass/users \
  -H "X-Vault-Token: your-root-token-here"
```

---

## 19.6 Test Results

| Test | Result |
|---|---|
| sara logs in → `frontend-dev` policy | ✅ |
| dani logs in → `backend-dev` policy | ✅ |
| Wrong password → `invalid username or password` | ✅ |
| sara reads `team/frontend` → OK | ✅ |
| sara reads `team/backend` → permission denied | ✅ |
| dani reads `team/backend` → OK | ✅ |
| lead reads both `frontend` and `backend` → OK | ✅ |
| Admin changes sara's password | ✅ |
| Login with new password → OK | ✅ |
| Login with old password → denied | ✅ |
| Delete dani → login denied | ✅ |

---

## 19.7 Userpass vs Other Auth Methods

| Property | Userpass | OIDC/Keycloak | TLS Cert | AppRole |
|---|---|---|---|---|
| Who manages credentials | Vault | External IdP | PKI / CA | Vault |
| MFA support | No (native) | Yes (via IdP) | Hardware tokens | No |
| Self-service password reset | Yes (with policy) | Yes (via IdP) | Via PKI | N/A |
| Best for | Small teams, labs | SSO-enabled orgs | Services with PKI | Machine auth |
| Password rotation | Manual | IdP handles | Cert renewal | secret_id rotation |

---

## API Reference

| Operation | Method | Path |
|---|---|---|
| Enable userpass | POST | `/v1/sys/auth/userpass` |
| Create user | POST | `/v1/auth/userpass/users/<name>` |
| Read user | GET | `/v1/auth/userpass/users/<name>` |
| Update user | POST | `/v1/auth/userpass/users/<name>` |
| Change password | POST | `/v1/auth/userpass/users/<name>/password` |
| Delete user | DELETE | `/v1/auth/userpass/users/<name>` |
| List users | LIST | `/v1/auth/userpass/users` |
| Login | POST | `/v1/auth/userpass/login/<name>` |
