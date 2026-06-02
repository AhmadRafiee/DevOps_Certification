# Level 4 — Transit Secrets Engine (Encryption as a Service)

### Requirements:
  - **Vault Service is Running** from level 0
  - **Vault Address:** `https://vault.lab.mecan.ir`
  - **Auth:** Root token `myroot` (dev mode only)
  - **Tools:** install `jq` command

---

## Overview

Transit is Vault's **encryption-as-a-service** engine.
The application sends plaintext to Vault and gets ciphertext back.
The encryption key **never leaves Vault** — the app never sees it, cannot export it,
and cannot be compromised into revealing it.

This solves a fundamental problem: if your app holds its own encryption key,
a database dump + config leak exposes everything. With Transit, the ciphertext
in your database is useless without an active Vault connection.

```
App ────> plaintext ────> Vault Transit ────> ciphertext ────> Database
App <─── plaintext <───── Vault Transit <─── ciphertext <───── Database
```

---

## 4.1 Enable Transit Engine

### Scenario
Transit is not mounted by default. An admin enables it once.

```bash
curl -X POST https://vault.lab.mecan.ir/v1/sys/mounts/transit \
  -H "X-Vault-Token: myroot" \
  -H "Content-Type: application/json" \
  -d '{"type": "transit"}'
```

![transit](../image/04.transit.png)

---

## 4.2 Create a Named Encryption Key

### Scenario
Each logical purpose gets its own key. Here we create one for the payment service
so its ciphertexts are isolated from other services' keys.

```bash
curl -X POST https://vault.lab.mecan.ir/v1/transit/keys/myapp-key \
  -H "X-Vault-Token: myroot" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "aes256-gcm96",
    "exportable": false
  }' | jq
```

![myapp-key](../image/04.myapp-key.png)

Key options:

| Option       | Value         | Meaning                                    |
|--------------|---------------|--------------------------------------------|
| `type`       | `aes256-gcm96`| AES-256 with GCM (authenticated encryption)|
| `exportable` | `false`       | Key material can never leave Vault         |

---

## 4.3 Encrypt and Decrypt

### Scenario
The payment service needs to store a credit card number in the database.
It encrypts the number before writing and decrypts on read. The database
only ever stores the ciphertext.

**Important:** Vault Transit requires plaintext to be **base64-encoded** before sending.

### Encrypt

```bash
# Step 1 — base64-encode your plaintext
PLAINTEXT="41111111111111114"
B64=$(echo -n "$PLAINTEXT" | base64)
# B64 = NDExMTExMTExMTExMTExMTQ=

# Step 2 — encrypt
curl -X POST https://vault.lab.mecan.ir/v1/transit/encrypt/myapp-key \
  -H "X-Vault-Token: myroot" \
  -H "Content-Type: application/json" \
  -d "{\"plaintext\": \"$B64\"}" | jq
```

Response:
```json
{
  "data": {
    "ciphertext": "vault:v1:zggyoPOdaAJvW3L9qz3CQZ...",
    "key_version": 1
  }
}
```

The `vault:v1:` prefix tells you which key version encrypted the data —
critical for key rotation later.

### Decrypt

```bash
curl -X POST https://vault.lab.mecan.ir/v1/transit/decrypt/myapp-key \
  -H "X-Vault-Token: myroot" \
  -H "Content-Type: application/json" \
  -d '{"ciphertext": "vault:v1:zggyoPOdaAJvW3L9qz3CQZ..."}' | jq
```

Response — decode the base64 to get the original value back:
```json
{
  "data": {
    "plaintext": "NDExMTExMTExMTExMTExMTQ="
  }
}
```

```bash
echo "NDExMTExMTExMTExMTExMTQ=" | base64 -d
# 41111111111111114
```

---

## 4.4 Key Rotation

### Scenario
The security team mandates quarterly key rotation. We rotate `myapp-key` to
generate v2. All **new** encryptions use v2. All **existing** v1 ciphertexts
remain decryptable — nothing in the database breaks.

### Rotate the key

```bash
curl -X POST https://vault.lab.mecan.ir/v1/transit/keys/myapp-key/rotate \
  -H "X-Vault-Token: myroot" | jq
```

After rotation:
- `latest_version: 2`
- `versions: [1, 2]`
- New encryptions produce `vault:v2:...`
- Old `vault:v1:...` ciphertexts still decrypt fine

---

## 4.5 Rewrap (Migrate Old Ciphertexts)

### Scenario
After rotation, old v1 ciphertexts still work but rely on the old key version.
Rewrapping re-encrypts them with the latest key version **without the app ever
seeing the plaintext**. Vault decrypts internally and re-encrypts with v2.

```bash
curl -X POST https://vault.lab.mecan.ir/v1/transit/rewrap/myapp-key \
  -H "X-Vault-Token: myroot" \
  -H "Content-Type: application/json" \
  -d '{"ciphertext": "vault:v1:zggyoPOdaAJvW3L9..."}' | jq
```

Response:
```json
{
  "data": {
    "ciphertext": "vault:v2:mlBfxRY/MJUso1PKqlNM..."
  }
}
```

The rewrapped ciphertext decrypts to the exact same plaintext.

---

## 4.6 Retire Old Key Versions

### Scenario
Once all records in the database have been rewrapped to v2, we enforce a policy
that prevents anyone from decrypting v1 ciphertexts. This limits what a
compromised Vault token can access.

```bash
curl -X POST https://vault.lab.mecan.ir/v1/transit/keys/myapp-key/config \
  -H "X-Vault-Token: myroot" \
  -H "Content-Type: application/json" \
  -d '{"min_decryption_version": 2}'
```

After this, any attempt to decrypt a `vault:v1:...` ciphertext returns:
```
ciphertext or signature version is disallowed by policy (too old)
```

---

## Full Key Lifecycle

```
Create key (v1)
      │
      ├── encrypt → vault:v1:...  (stored in DB)
      │
Rotate key → v2 created
      │
      ├── new encrypts → vault:v2:...
      ├── old vault:v1:... still decryptable
      │
Rewrap all v1 records → now vault:v2:... in DB
      │
Set min_decryption_version=2
      │
      └── vault:v1:... is now permanently blocked
```

![key-options](../image/04.key-options.png)

---

## API Reference

| Operation               | Method | Path                                    |
|-------------------------|--------|-----------------------------------------|
| Enable Transit          | POST   | `/v1/sys/mounts/transit`                |
| Create key              | POST   | `/v1/transit/keys/<name>`               |
| Read key metadata       | GET    | `/v1/transit/keys/<name>`               |
| Encrypt                 | POST   | `/v1/transit/encrypt/<name>`            |
| Decrypt                 | POST   | `/v1/transit/decrypt/<name>`            |
| Rotate key              | POST   | `/v1/transit/keys/<name>/rotate`        |
| Rewrap ciphertext       | POST   | `/v1/transit/rewrap/<name>`             |
| Configure key policy    | POST   | `/v1/transit/keys/<name>/config`        |
