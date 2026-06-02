# Level 21 — Auto-Unseal with Transit Seal

### Requirements:
  - **Vault Service is Running** from level 15
  - **Vault Address:** `https://vault.lab.mecan.ir`
  - **Auth:** Root token `your-root-token-here` (dev mode only)
  - **Tools:** install `jq` command

---

## Overview

In a normal Vault cluster, every restart requires operators to manually enter
unseal keys (Shamir's Secret Sharing). **Auto-Unseal** eliminates this by using
an external key management system — in this lab, another Vault's Transit engine
acts as the KMS.

```
Vault Cluster
  │ (restart)
  ├── reads encrypted root key from Raft storage
  └── PUT /v1/transit/decrypt/ha-unseal-key ──→ Transit Vault (KMS)
      ← decrypted root key ──────────────────
      ← Vault auto-unseals, no human needed ─
```

Instead of: operators receiving calls at 3 AM to enter 3 unseal keys
With auto-unseal: Vault unseals in seconds automatically

---

## 21.1 Setup on the "KMS" Vault (Transit)

```bash
# Enable transit engine
curl -X POST https://vault.lab.mecan.ir/v1/sys/mounts/transit \
  -H "X-Vault-Token: myroot" -d '{"type":"transit"}'

# Create a dedicated key for unsealing
curl -X POST https://vault.lab.mecan.ir/v1/transit/keys/ha-unseal-key \
  -H "X-Vault-Token: myroot" \
  -d '{"type":"aes256-gcm96","exportable":false}'

# Create restricted policy — only encrypt/decrypt on this key
curl -X PUT https://vault.lab.mecan.ir/v1/sys/policies/acl/ha-auto-unseal \
  -H "X-Vault-Token: myroot" \
  -d '{
    "policy": "path \"transit/encrypt/ha-unseal-key\" { capabilities = [\"update\"] }
              path \"transit/decrypt/ha-unseal-key\" { capabilities = [\"update\"] }"
  }'

# Create a long-lived token with this policy
UNSEAL_TOKEN=$(curl -s -X POST https://vault.lab.mecan.ir/v1/auth/token/create \
  -H "X-Vault-Token: myroot" \
  -d '{"policies":["ha-auto-unseal"],"ttl":"0","no_parent":true}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['auth']['client_token'])")
```

---

## 21.2 Vault Server Configuration

Add a `seal "transit"` block to `vault.hcl`:

```hcl
seal "transit" {
  address         = "http://172.19.0.2:8200"  # Transit Vault IP
  token           = "hvs.XXXX"                # Unseal token
  key_name        = "ha-unseal-key"
  mount_path      = "transit/"
  disable_renewal = "false"
}

telemetry {
  prometheus_retention_time = "30s"
  disable_hostname          = true
}
```

No changes to `storage`, `listener`, or other blocks.

---

## 21.3 Initialize with Transit Seal

When using transit seal, Vault does **not** generate Shamir unseal keys.
Instead, it generates recovery keys (for emergency access only):

```bash
curl -X POST http://localhost:8240/v1/sys/init \
  -d '{"recovery_shares": 3, "recovery_threshold": 2}'
```

Response — note: no `keys` field, only `recovery_keys`:
```json
{
  "root_token": "<YOUR_VAULT_ROOT_TOKEN>",
  "recovery_keys": [
    "eb13f34b99d20ec3b4d7e2fab0...",
    "5ccb5ea7c3f0315c2facb2155d...",
    "6d03f4429504fdfab793876d3a..."
  ]
}
```

After init, Vault is **immediately unsealed** — no unseal key input needed.

```bash
curl http://localhost:8240/v1/sys/health | python3 -c "
import sys,json; d=json.load(sys.stdin)
print(f'sealed={d[\"sealed\"]}')  # → sealed=False
"
```

---

## 21.4 Auto-Unseal After Restart

```bash
# Restart the vault container
docker restart vault-autounseal

# Wait ~15s — Vault auto-unseals with NO human intervention
curl http://localhost:8240/v1/sys/health
# → "sealed": false
```

Vault reads the encrypted root key from its storage, calls Transit to decrypt
it, and unseals automatically. The entire process takes a few seconds.

---

## 21.5 Test Results

| Test | Result |
|---|---|
| Init with transit seal — no Shamir keys generated | ✅ |
| Vault unsealed immediately after init | ✅ |
| Container restart → auto-unsealed in ~10s | ✅ |
| Secret written before restart — still accessible after | ✅ |
| Only encrypt/decrypt on `ha-unseal-key` allowed | ✅ |

---

## 21.6 Production Notes

### What auto-unseal does NOT protect against
If the Transit Vault (KMS) is unavailable, the cluster stays sealed.
Plan for KMS availability as part of your HA strategy.

### Recovery keys
Keep recovery keys in a safe offline location. They are used to:
- Generate a new root token
- Rekey the seal (change the auto-unseal key)
- Break glass access if the KMS is permanently lost

### AWS KMS alternative

```hcl
seal "awskms" {
  region     = "us-east-1"
  kms_key_id = "alias/vault-unseal"
  # Uses IAM role — no token needed
}
```

---

## API Reference

| Operation | Method | Path |
|---|---|---|
| Seal status | GET | `/v1/sys/seal-status` |
| Initialize (auto-unseal) | POST | `/v1/sys/init` with `recovery_shares` |
| Health | GET | `/v1/sys/health` |
| Unseal (Shamir, if needed) | POST | `/v1/sys/unseal` |
