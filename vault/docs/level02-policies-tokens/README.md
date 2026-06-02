# Level 2 — Policies and Tokens

### Requirements:
  - **Vault Service is Running** from level 0
  - **Vault Address:** `https://vault.lab.mecan.ir`
  - **Auth:** Root token `myroot` (dev mode only)
  - **Tools:** install `jq` command
  - **Secret from Level 1:** the secret at `secret/myapp/database` must exist (created in Level 1) — the READ test in 2.3 depends on it

---

## 2.1 Creating a Policy

### Scenario
A backend service needs to read database credentials from Vault at startup. It should have access **only** to its own secrets path and **cannot** write, delete, or access any other path. If the token is leaked, the blast radius is minimal.

### How it works
Vault uses **HCL-based ACL policies** to define what a token can and cannot do. Every token is attached to one or more policies. Without an explicit `allow`, access is denied by default.

Capability options: `read`, `list`, `create`, `update`, `delete`, `sudo`, `deny`

### Create a read-only policy for the app

```bash
curl -X PUT https://vault.lab.mecan.ir/v1/sys/policies/acl/myapp-readonly \
  -H "X-Vault-Token: myroot" \
  -H "Content-Type: application/json" \
  -d '{
    "policy": "path \"secret/data/myapp/*\" {\n  capabilities = [\"read\", \"list\"]\n}\n\npath \"secret/metadata/myapp/*\" {\n  capabilities = [\"list\"]\n}"
  }'
```

The same policy in readable HCL format:
```hcl
path "secret/data/myapp/*" {
  capabilities = ["read", "list"]
}

path "secret/metadata/myapp/*" {
  capabilities = ["list"]
}
```
![ui policy](../image/02-myapp-readonly.png)

---

## 2.2 Issuing a Token with the Policy

### Scenario
The backend service needs a token scoped to the `myapp-readonly` policy, with a TTL so it expires automatically even if forgotten.

### Create a scoped token

```bash
curl -X POST https://vault.lab.mecan.ir/v1/auth/token/create \
  -H "X-Vault-Token: myroot" \
  -H "Content-Type: application/json" \
  -d '{
    "policies": ["myapp-readonly"],
    "ttl": "1h",
    "display_name": "backend-service"
  }' | jq
```

Response contains the token the service will use:
```json
{
  "auth": {
    "client_token": "hvs.XXXX",
    "policies": ["myapp-readonly"],
    "lease_duration": 3600
  }
}
```

---

## 2.3 Testing Access Control

Replace `$APP_TOKEN` with the token from the previous step.
```bash
APP_TOKEN=$(curl -s -X POST https://vault.lab.mecan.ir/v1/auth/token/create \
  -H "X-Vault-Token: myroot" \
  -H "Content-Type: application/json" \
  -d '{"policies":["myapp-readonly"],"ttl":"1h","display_name":"backend-service"}' \
  | jq -r '.auth.client_token')
echo "[$APP_TOKEN]"
```

### READ — should succeed

```bash
curl https://vault.lab.mecan.ir/v1/secret/data/myapp/database \
  -H "X-Vault-Token: $APP_TOKEN" | jq
# Returns the secret data
```

### WRITE — should be denied

```bash
curl -X POST https://vault.lab.mecan.ir/v1/secret/data/myapp/database \
  -H "X-Vault-Token: $APP_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"data": {"password": "hacked"}}' | jq
# Returns: permission denied
```

### OTHER PATH — should be denied

```bash
curl https://vault.lab.mecan.ir/v1/secret/data/other/secret \
  -H "X-Vault-Token: $APP_TOKEN" | jq
# Returns: permission denied
```

---

## 2.4 Token TTL and Renewal

### Scenario
Tokens expire automatically. A long-running service needs to renew its token before expiry without re-authenticating. This is called **token renewal**.

### Check remaining TTL on a token

A service checks **its own** token with `lookup-self`. This is a **GET** request — the
`default` policy grants only `read` (GET) on `auth/token/lookup-self`, so sending `POST`
returns `permission denied`.

```bash
curl https://vault.lab.mecan.ir/v1/auth/token/lookup-self \
  -H "X-Vault-Token: $APP_TOKEN" | jq
```

> **Note:** use double quotes (or no quotes) around the header so the shell expands
> `$APP_TOKEN`. Inside single quotes the variable is sent literally and Vault replies
> `bad token`.

To inspect **another** token, an admin uses `lookup` with the root token in the header and the target token in the body. Note the escaped double quotes so `$APP_TOKEN` expands:


```bash
curl -X POST https://vault.lab.mecan.ir/v1/auth/token/lookup \
  -H "X-Vault-Token: myroot" \
  -H "Content-Type: application/json" \
  -d "{\"token\": \"$APP_TOKEN\"}" | jq
```

Key fields in the response:
```json
{
  "data": {
    "ttl": 3542,
    "expire_time": "2026-05-31T15:27:00Z",
    "policies": ["myapp-readonly"],
    "display_name": "backend-service"
  }
}
```

### Renew a token (self-renewal)

The service calls this with its own token to extend the TTL:

```bash
curl -X POST https://vault.lab.mecan.ir/v1/auth/token/renew-self \
  -H "X-Vault-Token: $APP_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"increment": "1h"}' | jq
```

### Revoke a token (on service shutdown)

Best practice: revoke the token when the service shuts down gracefully.

```bash
curl -X POST https://vault.lab.mecan.ir/v1/auth/token/revoke-self \
  -H "X-Vault-Token: $APP_TOKEN"
```

---

## API Reference

| Operation            | Method | Path                              |
|----------------------|--------|-----------------------------------|
| Create policy        | PUT    | `/v1/sys/policies/acl/<name>`     |
| Read policy          | GET    | `/v1/sys/policies/acl/<name>`     |
| List policies        | LIST   | `/v1/sys/policies/acl`            |
| Delete policy        | DELETE | `/v1/sys/policies/acl/<name>`     |
| Create token         | POST   | `/v1/auth/token/create`           |
| Lookup own token     | GET    | `/v1/auth/token/lookup-self`      |
| Lookup other token   | POST   | `/v1/auth/token/lookup`           |
| Renew token          | POST   | `/v1/auth/token/renew-self`       |
| Revoke token         | POST   | `/v1/auth/token/revoke-self`      |
