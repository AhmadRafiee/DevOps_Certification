# Level 5 — PKI Secrets Engine (Internal Certificate Authority)

### Requirements:
  - **Vault Service is Running** from level 0
  - **Vault Address:** `https://vault.lab.mecan.ir`
  - **Auth:** Root token `myroot` (dev mode only)
  - **Tools:** install `jq` command

---

## Overview

Vault can act as a full internal Certificate Authority.
Instead of buying certificates from a public CA or managing a separate CA tool,
every service requests a short-lived TLS certificate from Vault at startup.

Why short TTLs matter:

| Approach         | Cert lifetime | Compromise window       |
|------------------|---------------|-------------------------|
| Traditional CA   | 1–2 years     | Up to 2 years           |
| Vault PKI        | 24h–30 days   | Until cert expires      |

If a cert is leaked, it's useless within hours — no revocation required.

---

## Architecture: Root CA → Intermediate CA → Leaf Certs

```
Root CA  (pki mount, 10-year cert, offline-style)
  └── Intermediate CA  (pki_int mount, 5-year cert, signs daily certs)
        ├── api.lab.mecan.ir        (24h)
        ├── payments.lab.mecan.ir   (24h)
        └── db.svc.cluster.local    (24h)
```

The Root CA only signs the Intermediate CA once.
All leaf certificates come from the Intermediate CA.

---

## 5.1 Enable PKI Engine (Root CA)

```bash
curl -X POST https://vault.lab.mecan.ir/v1/sys/mounts/pki \
  -H "X-Vault-Token: myroot" \
  -H "Content-Type: application/json" \
  -d '{"type": "pki", "config": {"max_lease_ttl": "87600h"}}'
```

`87600h` = 10 years — the maximum TTL for any cert issued from this mount.

![pki](../image/05.pki.png)
---

## 5.2 Generate Root CA

The key is generated and stored **inside Vault** — it never leaves.

```bash
curl -X POST https://vault.lab.mecan.ir/v1/pki/root/generate/internal \
  -H "X-Vault-Token: myroot" \
  -H "Content-Type: application/json" \
  -d '{
    "common_name": "lab.mecan.ir Root CA",
    "ttl": "87600h",
    "key_type": "rsa",
    "key_bits": 4096
  }' | jq
```

Then set the CA and CRL URLs so clients know where to find revocation info:


```bash
curl -X POST https://vault.lab.mecan.ir/v1/pki/config/urls \
  -H "X-Vault-Token: myroot" \
  -H "Content-Type: application/json" \
  -d '{
    "issuing_certificates": "https://vault.lab.mecan.ir/v1/pki/ca",
    "crl_distribution_points": "https://vault.lab.mecan.ir/v1/pki/crl"
  }' | jq
```

![root-ca](../image/05.root-ca.png)

---

## 5.3 Set Up Intermediate CA

### Enable the mount

```bash
curl -X POST https://vault.lab.mecan.ir/v1/sys/mounts/pki_int \
  -H "X-Vault-Token: myroot" \
  -H "Content-Type: application/json" \
  -d '{"type": "pki", "config": {"max_lease_ttl": "43800h"}}'
```

![pki-int](../image/05.pki-int.png)

### Generate a CSR from the Intermediate CA

```bash
curl -X POST https://vault.lab.mecan.ir/v1/pki_int/intermediate/generate/internal \
  -H "X-Vault-Token: myroot" \
  -H "Content-Type: application/json" \
  -d '{
    "common_name": "lab.mecan.ir Intermediate CA",
    "key_type": "rsa",
    "key_bits": 2048
  }' | jq
# Save the "csr" field from the response
```

### Sign the CSR with Root CA

```bash
curl -X POST https://vault.lab.mecan.ir/v1/pki/root/sign-intermediate \
  -H "X-Vault-Token: myroot" \
  -H "Content-Type: application/json" \
  -d '{
    "csr": "<CSR from previous step>",
    "common_name": "lab.mecan.ir Intermediate CA",
    "ttl": "43800h"
  }'
# Save the "certificate" field from the response
```

### Import signed cert back

```bash
curl -X POST https://vault.lab.mecan.ir/v1/pki_int/intermediate/set-signed \
  -H "X-Vault-Token: myroot" \
  -H "Content-Type: application/json" \
  -d '{"certificate": "<signed cert from previous step>"}'
```

![pki-int-cert](../image/05.pki-int-cert.png)

### Configure Intermediate CA URLs

```bash
curl -X POST https://vault.lab.mecan.ir/v1/pki_int/config/urls \
  -H "X-Vault-Token: myroot" \
  -H "Content-Type: application/json" \
  -d '{
    "issuing_certificates": "https://vault.lab.mecan.ir/v1/pki_int/ca",
    "crl_distribution_points": "https://vault.lab.mecan.ir/v1/pki_int/crl"
  }' | jq
```

---

## 5.4 Create an Issuance Role

A **role** defines the rules for what kind of leaf certs can be issued:
which domains are allowed, max TTL, key type, etc.

```bash
curl -X POST https://vault.lab.mecan.ir/v1/pki_int/roles/internal-services \
  -H "X-Vault-Token: myroot" \
  -H "Content-Type: application/json" \
  -d '{
    "allowed_domains": ["lab.mecan.ir", "svc.cluster.local"],
    "allow_subdomains": true,
    "max_ttl": "720h",
    "key_type": "rsa",
    "key_bits": 2048
  }' | jq
```

| Option            | Value                                    | Meaning                           |
|-------------------|------------------------------------------|-----------------------------------|
| `allowed_domains` | `lab.mecan.ir`, `svc.cluster.local`      | Only these domains can be issued  |
| `allow_subdomains`| `true`                                   | `api.lab.mecan.ir` is allowed     |
| `max_ttl`         | `720h` (30 days)                         | No cert lasts more than 30 days   |

---

## 5.5 Issue a Leaf Certificate

### Scenario
The `api` service starts. It calls Vault to get a TLS certificate for itself.
The cert is valid for 24 hours. Tomorrow it requests a new one.

```bash
curl -X POST https://vault.lab.mecan.ir/v1/pki_int/issue/internal-services \
  -H "X-Vault-Token: myroot" \
  -H "Content-Type: application/json" \
  -d '{
    "common_name": "api.lab.mecan.ir",
    "ttl": "24h"
  }' | jq
```

Response contains everything the service needs:

```json
{
  "data": {
    "certificate":    "-----BEGIN CERTIFICATE-----\n...",
    "private_key":    "-----BEGIN RSA PRIVATE KEY-----\n...",
    "issuing_ca":     "-----BEGIN CERTIFICATE-----\n...",
    "ca_chain":       ["-----BEGIN CERTIFICATE-----\n..."],
    "serial_number":  "7f:02:9e:ad:...",
    "expiration":     1748788631
  }
}
```

### Verify with openssl

```bash
# create cert and key file with command 
curl -s -X POST https://vault.lab.mecan.ir/v1/pki_int/issue/internal-services \
  -H "X-Vault-Token: myroot" \
  -H "Content-Type: application/json" \
  -d '{"common_name":"api.lab.mecan.ir","ttl":"24h"}' > resp.json

jq -r '.data.certificate' resp.json > api.crt
jq -r '.data.private_key' resp.json > api.key
jq -r '.data.ca_chain[]'   resp.json > ca-chain.crt

# Save cert and CA to files
openssl x509 -in api.crt -noout -subject -issuer -dates -ext subjectAltName

# subject=CN = api.lab.mecan.ir
# issuer=CN = lab.mecan.ir Intermediate CA
# notBefore=May 31 14:36:41 2026 GMT
# notAfter=Jun  1 14:37:11 2026 GMT
# DNS:api.lab.mecan.ir

# Verify chain (intermediate + root combined)
cat intermediate.crt root-ca.crt > chain.crt
openssl verify -CAfile chain.crt api.crt
# api.crt: OK
```

---

## 5.6 Revoke a Certificate

### Scenario
A service was compromised. The certificate must be revoked immediately —
even though it would expire tomorrow, we do not want to wait.

```bash
curl -X POST https://vault.lab.mecan.ir/v1/pki_int/revoke \
  -H "X-Vault-Token: myroot" \
  -H "Content-Type: application/json" \
  -d '{"serial_number": "7f:02:9e:ad:26:33:e8:b3:..."}'
```

Response:
```json
{
  "data": {
    "revocation_time": 1748706462,
    "revocation_time_rfc3339": "2026-05-31T14:37:42Z"
  }
}
```

The CRL is updated immediately. Clients that check the CRL endpoint
(`/v1/pki_int/crl`) will reject the revoked cert from this point.

```bash
# Confirm the CRL was updated
curl -s https://vault.lab.mecan.ir/v1/pki_int/crl/pem | \
  openssl crl -noout -lastupdate -nextupdate
```

---

## API Reference

| Operation                    | Method | Path                                              |
|------------------------------|--------|---------------------------------------------------|
| Enable PKI mount             | POST   | `/v1/sys/mounts/<name>`                           |
| Generate Root CA             | POST   | `/v1/pki/root/generate/internal`                  |
| Set CA/CRL URLs              | POST   | `/v1/pki/config/urls`                             |
| Generate Intermediate CSR    | POST   | `/v1/pki_int/intermediate/generate/internal`      |
| Sign Intermediate with Root  | POST   | `/v1/pki/root/sign-intermediate`                  |
| Import signed Intermediate   | POST   | `/v1/pki_int/intermediate/set-signed`             |
| Create issuance role         | POST   | `/v1/pki_int/roles/<name>`                        |
| Issue leaf certificate       | POST   | `/v1/pki_int/issue/<role>`                        |
| Revoke certificate           | POST   | `/v1/pki_int/revoke`                              |
| Download CRL                 | GET    | `/v1/pki_int/crl/pem`                             |
| Download CA cert             | GET    | `/v1/pki_int/ca/pem`                              |
