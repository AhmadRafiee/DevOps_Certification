# Level 6 — Audit Logging

### Requirements:
  - **Vault Service is Running** from level 0
  - **Vault Address:** `https://vault.lab.mecan.ir`
  - **Auth:** Root token `myroot` (dev mode only)
  - **Tools:** install `jq` command

---

## Overview

Every request to Vault — successful or not — can be written to an audit log.
This gives a complete, tamper-evident record of who accessed what and when.

Key properties of Vault audit logs:
- **Every request and response** is logged, including failures
- **Sensitive values** (tokens, passwords) are HMAC-SHA256 hashed before writing
- **At least one audit device must be healthy** for Vault to serve requests — if all devices fail, Vault goes into lockdown to preserve the audit trail

---

## 6.1 Enable File Audit Device

### Scenario
The security team requires a full audit trail of all Vault operations written to a persistent file. The file is on a volume that a log shipper (Filebeat, Fluentd) can read and forward to a SIEM.

The compose file mounts the log volume:

```yaml
volumes:
  - vault-logs:/vault/logs
```

Enable the audit device:

```bash
curl -X PUT https://vault.lab.mecan.ir/v1/sys/audit/file \
  -H "X-Vault-Token: myroot" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "file",
    "options": {
      "file_path": "/vault/logs/audit.log"
    }
  }' 
```

List active audit devices:

```bash
curl https://vault.lab.mecan.ir/v1/sys/audit \
  -H "X-Vault-Token: myroot" | jq
```

---

## 6.2 Audit Log Format

Each event is a single-line JSON object. Vault writes two entries per operation:
a `request` entry when the call arrives, and a `response` entry when it completes.

### Example: successful read

```json
{
  "type": "request",
  "time": "2026-05-31T14:40:14.114562122Z",
  "request": {
    "id": "3dbd68ea-12bc-0ef2-9852-5a6017ec8df2",
    "operation": "read",
    "path": "secret/data/myapp/database",
    "remote_address": "172.19.0.1"
  },
  "auth": {
    "token_type": "service",
    "accessor": "hmac-sha256:d72f3ed5...",
    "policies": ["root"]
  },
  "error": null
}
```

### Example: failed request (bad token)

```json
{
  "type": "response",
  "time": "2026-05-31T14:40:14Z",
  "request": {
    "operation": "read",
    "path": "secret/data/myapp/database"
  },
  "auth": {
    "accessor": "-"
  },
  "error": "2 errors occurred: * permission denied"
}
```

---

## 6.3 HMAC Hashing of Sensitive Values

### Scenario
A developer asks: "does the token appear in the audit log? Could an attacker who
reads the log file use it to authenticate?"

The answer is **no**. Vault HMAC-SHA256 hashes all sensitive values before writing.
The raw token never appears in the log — only its hash.

From a real audit log entry:
```
"client_token": "hmac-sha256:bfa02c5b6a288283..."
"accessor":     "hmac-sha256:d72f3ed5fe0facc8..."
```

To verify a specific token against the log, use:

```bash
curl -X POST https://vault.lab.mecan.ir/v1/sys/audit-hash/file \
  -H "X-Vault-Token: myroot" \
  -H "Content-Type: application/json" \
  -d '{"input": "hvs.actual-token-here"}'
```

The hash in the response will match what appears in the log.

---

## 6.4 What Gets Logged

| Event type              | Logged? |
|-------------------------|---------|
| Successful secret read  | Yes     |
| Failed auth attempt     | Yes     |
| Token creation          | Yes     |
| Policy change           | Yes     |
| Lease renewal           | Yes     |
| Lease revocation        | Yes     |
| Vault seal/unseal       | Yes     |

Every field in the request and response is present — including `remote_address`,
user-agent, namespace, and the full request path.

---

## 6.5 Disable an Audit Device

If you need to rotate or replace the audit device:

```bash
curl -X DELETE https://vault.lab.mecan.ir/v1/sys/audit/file \
  -H "X-Vault-Token: myroot"
```

**Warning:** if this is the only audit device, Vault will refuse all requests
until a new audit device is enabled.

---

## API Reference

| Operation              | Method | Path                              |
|------------------------|--------|-----------------------------------|
| Enable audit device    | PUT    | `/v1/sys/audit/<name>`            |
| List audit devices     | GET    | `/v1/sys/audit`                   |
| Hash a value           | POST   | `/v1/sys/audit-hash/<name>`       |
| Disable audit device   | DELETE | `/v1/sys/audit/<name>`            |
