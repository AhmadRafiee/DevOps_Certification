# Level 18 — TLS Certificate Authentication

### Requirements:
  - **Vault Service is Running** from level 15
  - **Vault Address:** `https://vault.lab.mecan.ir`
  - **Auth:** Root token `your-root-token-here` (dev mode only)
  - **Tools:** install `jq` command

---

## Overview

TLS Certificate auth allows clients to authenticate to Vault using an X.509
client certificate — no passwords, no tokens to manage. The certificate itself
is the credential.

```
CA signs client cert for alice (OU=developers)
alice ──── TLS handshake with cert ──→ Vault
Vault ── verifies: cert signed by trusted CA? OU matches role? ──→ issues token
```

This is ideal for:
- Machine-to-machine auth (services, CI/CD runners, cron jobs)
- Environments with existing PKI infrastructure
- High-security setups where passwords are forbidden

---

## 18.1 Certificate Hierarchy

```
Root CA  (ca.crt / ca.key)
├── Vault server cert  (vault-server.crt)  ← used by Vault's TLS listener
├── alice.crt          (CN=alice, OU=developers)  ← client cert
├── bob.crt            (CN=bob, OU=ops)            ← client cert
└── mallory.crt        (signed by rogue CA — untrusted)
```

---

## 18.2 Generate Certificates

### Root CA

```bash
mkdir -p certs

# CA key
openssl genrsa -out certs/ca.key 4096

# Self-signed CA cert (10 years)
openssl req -x509 -new -nodes \
  -key certs/ca.key -sha256 -days 3650 \
  -subj "/CN=Vault-Lab-CA/O=MeCan/OU=Lab" \
  -out certs/ca.crt
```

### Vault Server Certificate

```bash
# Config file for SANs
cat > vault-server-ext.cnf << 'EOF'
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[v3_req]
subjectAltName = @alt_names
[alt_names]
DNS.1 = vault-tls
DNS.2 = localhost
IP.1  = 127.0.0.1
EOF

openssl genrsa -out certs/vault-server.key 2048
openssl req -new -key certs/vault-server.key \
  -subj "/CN=vault-tls/O=MeCan" -out certs/vault-server.csr
openssl x509 -req -in certs/vault-server.csr \
  -CA certs/ca.crt -CAkey certs/ca.key -CAcreateserial \
  -days 365 -sha256 \
  -extfile vault-server-ext.cnf -extensions v3_req \
  -out certs/vault-server.crt
```

### Client Certificates

```bash
# alice — developer
openssl genrsa -out certs/alice.key 2048
openssl req -new -key certs/alice.key \
  -subj "/CN=alice/O=MeCan/OU=developers" -out certs/alice.csr
openssl x509 -req -in certs/alice.csr \
  -CA certs/ca.crt -CAkey certs/ca.key -CAcreateserial \
  -days 365 -sha256 -out certs/alice.crt

# bob — ops
openssl genrsa -out certs/bob.key 2048
openssl req -new -key certs/bob.key \
  -subj "/CN=bob/O=MeCan/OU=ops" -out certs/bob.csr
openssl x509 -req -in certs/bob.csr \
  -CA certs/ca.crt -CAkey certs/ca.key -CAcreateserial \
  -days 365 -sha256 -out certs/bob.crt
```

---

## 18.3 Vault Configuration with TLS

`config/vault.hcl`:

```hcl
storage "file" {
  path = "/vault/data"
}

listener "tcp" {
  address     = "0.0.0.0:8300"
  tls_cert_file = "/vault/certs/vault-server.crt"
  tls_key_file  = "/vault/certs/vault-server.key"

  # Needed to allow client cert auth but not require it for all connections
  tls_client_ca_file                 = "/vault/certs/ca.crt"
  tls_require_and_verify_client_cert = false
}

ui            = true
disable_mlock = true
```

`tls_require_and_verify_client_cert = false` means Vault accepts connections
without a client cert (for the root token login), but the cert auth method
validates the cert when presented.

---

## 18.4 Enable Cert Auth

```bash
export ROOT_TOKEN=your-root-token-here
curl -X POST https://vault.lab.mecan.ir/v1/sys/auth/cert \
  --cacert certs/ca.crt \
  -H "X-Vault-Token: $ROOT_TOKEN" \
  -d '{"type": "cert"}'
```

---

## 18.5 Create Cert Auth Roles

A **role** defines which certificates are allowed and what policies they get.
Matching can be done on:
- `certificate` — the CA cert (trusts any cert signed by this CA)
- `allowed_common_names` — specific CN values (exact or glob)
- `allowed_organizational_units` — OU field values
- `allowed_dns_sans` — SANs in the cert
- `allowed_email_sans` — email SANs

### Role for developers (match by OU)

```bash
CA_CERT_PEM=$(cat certs/ca.crt)

curl -X POST https://vault.lab.mecan.ir/v1/auth/cert/certs/developers \
  --cacert certs/ca.crt \
  -H "X-Vault-Token: $ROOT_TOKEN" \
  -d "{
    \"certificate\": \"$CA_CERT_PEM\",
    \"allowed_organizational_units\": \"developers\",
    \"token_policies\": [\"dev-policy\"],
    \"token_ttl\": \"1h\"
  }"
```

### Role for ops (match by OU)

```bash
curl -X POST https://vault.lab.mecan.ir/v1/auth/cert/certs/ops \
  --cacert certs/ca.crt \
  -H "X-Vault-Token: $ROOT_TOKEN" \
  -d "{
    \"certificate\": \"$CA_CERT_PEM\",
    \"allowed_organizational_units\": \"ops\",
    \"token_policies\": [\"ops-policy\"],
    \"token_ttl\": \"30m\"
  }"
```

---

## 18.6 Authenticate with a Certificate

```bash
# Login — present client cert during TLS handshake
curl -X POST https://vault.lab.mecan.ir/v1/auth/cert/login \
  --cacert certs/ca.crt \
  --cert certs/alice.crt \
  --key certs/alice.key
```

Response:
```json
{
  "auth": {
    "client_token": "hvs.XXXX",
    "policies": ["default", "dev-policy"],
    "lease_duration": 3600
  }
}
```

Login with a specific role name (when cert matches multiple roles):
```bash
curl -X POST https://vault.lab.mecan.ir/v1/auth/cert/login \
  --cacert certs/ca.crt \
  --cert certs/alice.crt \
  --key certs/alice.key \
  -d '{"name": "developers"}'
```

---

## 18.7 Test Results

| Test | Certificate | Expected | Result |
|---|---|---|---|
| alice login | OU=developers, signed by trusted CA | ✅ dev-policy | ✅ |
| bob login | OU=ops, signed by trusted CA | ✅ ops-policy | ✅ |
| mallory login | OU=developers, signed by **rogue** CA | ❌ denied | ✅ |
| No cert login | None | ❌ denied | ✅ |
| alice reads `dev/*` | dev-policy allows | ✅ | ✅ |
| alice reads `ops/*` | dev-policy denies | ❌ denied | ✅ |
| bob reads `dev/*` | ops-policy allows | ✅ | ✅ |
| bob reads `ops/*` | ops-policy allows | ✅ | ✅ |

---

## 18.8 Cert Auth vs Other Methods

| Method | Credential | Best for |
|---|---|---|
| Token | Static token | Bootstrapping only |
| AppRole | role_id + secret_id | Services without existing PKI |
| **TLS Cert** | **X.509 certificate** | **Services with existing PKI, hardware tokens** |
| Kubernetes | SA JWT | Pods in Kubernetes |
| JWT/OIDC | JWT from IdP | Human users via SSO |

TLS cert auth is the strongest for machine auth because:
- Private key never leaves the machine (no network transmission of credentials)
- Certificate revocation via CRL/OCSP
- Hardware-backed if using HSM or TPM

---

## API Reference

| Operation | Method | Path |
|---|---|---|
| Enable cert auth | POST | `/v1/sys/auth/cert` |
| Create role | POST | `/v1/auth/cert/certs/<name>` |
| Read role | GET | `/v1/auth/cert/certs/<name>` |
| List roles | LIST | `/v1/auth/cert/certs` |
| Login | POST | `/v1/auth/cert/login` |
