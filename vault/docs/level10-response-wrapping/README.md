# Level 10 — Response Wrapping

### Requirements:
  - **Vault Service is Running** from level 0
  - **Vault Address:** `https://vault.lab.mecan.ir`
  - **Auth:** Root token `myroot` (dev mode only)
  - **Tools:** install `jq` command

---

## Overview

Response Wrapping solves the **secret zero problem**: how do you securely deliver
a secret to a service that doesn't have credentials yet?

Instead of sending the actual secret, Vault wraps it in a **one-time-use token**
with a short TTL. Only the first unwrap succeeds. If someone intercepts the token
and unwraps it before the intended recipient, the recipient gets an error and
knows the delivery was compromised.

```
Vault ─── wrap(secret) ──> wrapping_token ──> (transit) ──> Service
                                                    ↑
                                              [intercepted?]
Service ─── unwrap(token) ──> Vault ─── success (first) or ALERT (already used)
```

---

## 10.1 Wrap a Secret

Add the `X-Vault-Wrap-TTL` header to any Vault request to wrap its response.
The actual data is hidden — only a wrapping token is returned.

```bash
curl https://vault.lab.mecan.ir/v1/secret/data/myapp/database \
  -H "X-Vault-Token: myroot" \
  -H "X-Vault-Wrap-TTL: 60" | jq
```

Response — note that `data` is `null`. The real data is stored inside the token:

```json
{
  "wrap_info": {
    "token": "hvs.CAESIA52ZUX3UM8z2FEsp...",
    "ttl": 60,
    "creation_time": "2026-05-31T15:06:35Z",
    "creation_path": "secret/data/myapp/database"
  },
  "data": null
}
```

`X-Vault-Wrap-TTL` accepts:
- Seconds: `60`
- Duration strings: `5m`, `1h`, `24h`

---

## 10.2 Unwrap (First Use — Succeeds)

The recipient calls the unwrap endpoint using the wrapping token as their auth:

```bash
curl -X POST https://vault.lab.mecan.ir/v1/sys/wrapping/unwrap \
  -H "X-Vault-Token: hvs.CAESIA52ZUX3UM8z2FEsp..."
```

Response — the actual secret data:

```json
{
  "data": {
    "data": {
      "host": "db-replica.internal",
      "username": "appuser",
      "password": "brand-new-pass-v4"
    }
  }
}
```

The wrapping token is **destroyed immediately** after unwrapping.

---

## 10.3 Unwrap (Second Use — Fails)

Any subsequent unwrap attempt with the same token returns an error:

```bash
curl -X POST https://vault.lab.mecan.ir/v1/sys/wrapping/unwrap \
  -H "X-Vault-Token: hvs.CAESIA52ZUX3UM8z2FEsp..."
```

```json
{
  "errors": ["wrapping token is not valid or does not exist"]
}
```

---

## 10.4 Lookup Without Consuming

An admin can inspect a wrapping token without consuming it — useful for
verifying delivery before the recipient uses it:

```bash
curl -X POST https://vault.lab.mecan.ir/v1/sys/wrapping/lookup \
  -H "X-Vault-Token: myroot" \
  -H "Content-Type: application/json" \
  -d '{"token": "hvs.CAESIA52ZUX3UM8z2FEsp..."}'
```

Response:
```json
{
  "data": {
    "creation_path": "secret/data/myapp/database",
    "creation_ttl": 120,
    "creation_time": "2026-05-31T15:06:59Z"
  }
}
```

---

## 10.5 Interception Detection

### Scenario
A CI/CD system generates a `secret_id` for AppRole and wraps it before
sending to a service. The service expects to be the first (and only) one
to unwrap it. If the token was already consumed when the service tries to
unwrap, it knows the delivery channel was compromised.

**Normal flow:**

```
CI/CD ─── wrap(secret_id, TTL=60s) ──> wrapping_token ──> Service
Service ─── unwrap(token) ──────────────────────────────> success → gets secret_id
```

**Compromised flow — interception detected:**

```
CI/CD ─── wrap(secret_id) ──→ wrapping_token ──> [Attacker intercepts]
                                                        │
                                               Attacker unwraps → gets secret_id
                                                        │
Service ─── unwrap(token) ──> ALREADY CONSUMED → ERROR
Service ─── ALERT: possible man-in-the-middle ────────> stops and alerts ops
```

From the live test:

```
Attacker got: ['host', 'password', 'port', 'username']   ← attacker wins the race

Legitimate recipient:
ALERT: Token already consumed — possible interception!
Error: wrapping token is not valid or does not exist
```

---

## 10.6 Common Use Cases

| Use case                        | Wrap what                         | TTL          |
|---------------------------------|-----------------------------------|--------------|
| AppRole bootstrap               | `secret_id`                       | 60–300s      |
| Deliver DB password to new service | KV secret read               | 5–15m        |
| Pass PKI cert to another system | PKI issue response                | 30s          |
| CI/CD secret injection          | Any secret                        | Pipeline time|

---

## API Reference

| Operation              | Method | Path                              |
|------------------------|--------|-----------------------------------|
| Wrap a response        | Any    | Any endpoint + `X-Vault-Wrap-TTL` header |
| Unwrap a token         | POST   | `/v1/sys/wrapping/unwrap`         |
| Lookup (non-destructive)| POST  | `/v1/sys/wrapping/lookup`         |
| Rewrap to extend TTL   | POST   | `/v1/sys/wrapping/rewrap`         |
