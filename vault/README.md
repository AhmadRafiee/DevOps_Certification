# HashiCorp Vault — Lab Documentation

A complete hands-on lab covering HashiCorp Vault from zero to production patterns.
All scenarios are tested live against a running Vault instance and documented with
real API calls, outputs, and explanations.

---

## Infrastructure

Each service lives in its own level directory and is started independently.

| Service | Container | Port | Level | Description |
|---|---|---|---|---|
| Vault (dev) | `hashicorp_vault` | `8200` | `level00-setup` | Main lab instance — dev mode |
| PostgreSQL | `vault_postgres` | `5432` | `level07-dynamic-secrets-db` | Dynamic DB secrets backend |
| SSH Server | `vault_ssh_server` | `2222` (cert) / `2223` (OTP) | `level09-ssh-secrets-engine` | SSH secrets target |
| Keycloak | `vault_keycloak` | `8080` | `level14-keycloak-oidc` | OIDC identity provider |
| Vault HA Node 1 | `vault-node-1` | `8210` | `level15-ha-raft-persistence` | Raft HA cluster |
| Vault HA Node 2 | `vault-node-2` | `8220` | `level15-ha-raft-persistence` | Raft HA cluster |
| Vault HA Node 3 | `vault-node-3` | `8230` | `level15-ha-raft-persistence` | Raft HA cluster |
| RabbitMQ | `vault_rabbitmq` | `5672` / `15672` | `level16-rabbitmq-redis-dynamic-secrets` | Dynamic credential backend |
| Redis | `vault_redis` | `6379` | `level16-rabbitmq-redis-dynamic-secrets` | Dynamic credential backend |

**Vault Address:** `https://vault.lab.mecan.ir`
**Dev Root Token:** `myroot`

---

## Quick Start

```bash
# Start core Vault instance (dev mode)
cd docs/level00-setup && docker compose up -d

# Verify Vault is running
curl https://vault.lab.mecan.ir/v1/sys/health | python3 -m json.tool

# Start HA cluster
cd docs/level15-ha-raft-persistence && docker compose up -d

# Start a specific lab service (e.g. PostgreSQL for level 07)
cd docs/level07-dynamic-secrets-db && docker compose up -d
```

---

## Project Structure

```
vault/
├── README.md                              ← This file
├── image/                                 ← Screenshots referenced in docs
└── docs/                                  ← One directory per lab level
    ├── level00-setup/                     ← Foundation: Vault dev instance
    │   ├── compose.yml
    │   └── README.md
    ├── level07-dynamic-secrets-db/
    │   ├── compose.yml                    ← PostgreSQL service
    │   └── README.md
    ├── level09-ssh-secrets-engine/
    │   ├── compose.yml                    ← Custom SSH server image
    │   ├── Dockerfile
    │   ├── sshd_config
    │   └── README.md
    ├── level14-keycloak-oidc/
    │   ├── compose.yml                    ← Keycloak service
    │   └── README.md
    ├── level15-ha-raft-persistence/
    │   ├── compose.yml                    ← 3-node Raft cluster
    │   ├── config/                        ← Per-node HCL configs
    │   │   ├── vault-1.hcl
    │   │   ├── vault-2.hcl
    │   │   └── vault-3.hcl
    │   ├── data/                          ← Persistent Raft storage
    │   └── README.md
    ├── level16-rabbitmq-redis-dynamic-secrets/
    │   ├── compose.yml                    ← RabbitMQ + Redis
    │   └── README.md
    ├── level18-tls-cert-auth/
    │   ├── config/vault.hcl              ← TLS Vault instance config
    │   └── README.md
    ├── level21-auto-unseal/
    │   ├── auto-unseal/
    │   │   └── config/vault.hcl          ← Transit seal config
    │   └── README.md
    ├── level22-prometheus-grafana/
    │   ├── monitoring/
    │   │   ├── prometheus/
    │   │   │   └── prometheus.yml
    │   │   └── grafana/
    │   │       └── provisioning/
    │   └── README.md
    └── level01-kv-secrets/ … level23-vault-secrets-operator/
        └── README.md                      ← Documentation-only levels
```

---

## Levels

### Foundation

| Level | Topic | Description | Doc |
|---|---|---|---|
| 00 | **Setup** | Docker Compose infrastructure, key concepts, how to start/stop | [→](docs/level00-setup/) |
| 01 | **KV Secrets** | Write, read, version, soft-delete, hard-destroy secrets | [→](docs/level01-kv-secrets/) |
| 02 | **Policies & Tokens** | ACL policies, scoped tokens, TTL, renewal, revocation | [→](docs/level02-policies-tokens/) |

### Authentication Methods

| Level | Topic | Description | Doc |
|---|---|---|---|
| 03 | **AppRole Auth** | Machine auth with role_id + secret_id, use limits, CI/CD pattern | [→](docs/level03-approle-auth/) |
| 13 | **Kubernetes Auth** | Pod auth via ServiceAccount JWT, TokenReview, k8s role binding | [→](docs/level13-kubernetes-auth/) |
| 14 | **Keycloak OIDC/JWT** | SSO with Keycloak, group claims, JWT token exchange | [→](docs/level14-keycloak-oidc/) |
| 18 | **TLS Certificate Auth** | X.509 client cert auth, CA trust, OU-based role matching | [→](docs/level18-tls-cert-auth/) |
| 19 | **Username/Password** | Built-in user management, password policy, self-service | [→](docs/level19-userpass-auth/) |

### Secrets Engines

| Level | Topic | Description | Doc |
|---|---|---|---|
| 04 | **Transit Engine** | Encryption as a service, key rotation, rewrap, retire versions | [→](docs/level04-transit-engine/) |
| 05 | **PKI Engine** | Internal CA, intermediate CA, issue certs, CRL, revocation | [→](docs/level05-pki-engine/) |
| 07 | **PostgreSQL Dynamic Secrets** | On-demand DB credentials, TTL, lease renewal/revocation | [→](docs/level07-dynamic-secrets-db/) |
| 16 | **RabbitMQ & Redis Dynamic Secrets** | Temporary message broker and cache credentials | [→](docs/level16-rabbitmq-redis-dynamic-secrets/) |

### SSH

| Level | Topic | Description | Doc |
|---|---|---|---|
| 09 | **SSH Signed Certificates** | Vault as SSH CA, short-lived certs, role-based access | [→](docs/level09-ssh-secrets-engine/) |
| 11 | **SSH OTP** | One-time passwords for SSH, vault-ssh-helper, single-use enforcement | [→](docs/level11-ssh-otp/) |

### Advanced Patterns

| Level | Topic | Description | Doc |
|---|---|---|---|
| 06 | **Audit Logging** | File audit device, HMAC token hashing, event structure | [→](docs/level06-audit-logging/) |
| 08 | **Vault Agent** | Auto-auth, token renewal, template rendering, hot-reload | [→](docs/level08-vault-agent/) |
| 10 | **Response Wrapping** | One-time tokens, secret delivery, interception detection | [→](docs/level10-response-wrapping/) |
| 12 | **Cubbyhole & One-Time Access** | Per-token private storage, num_uses tokens, bootstrap pattern | [→](docs/level12-cubbyhole-one-time-access/) |

### Identity & Access Management

| Level | Topic | Description | Doc |
|---|---|---|---|
| 20 | **Groups & Policies** | Entities, aliases, internal/external groups, policy stacking | [→](docs/level20-groups-policies/) |

### Production Operations

| Level | Topic | Description | Doc |
|---|---|---|---|
| 15 | **HA + Raft + Persistence** | 3-node Raft cluster, leader election, failover, persistent storage | [→](docs/level15-ha-raft-persistence/) |
| 17 | **Backup & Restore** | Raft snapshots, checksum verification, automated backup script | [→](docs/level17-backup-restore/) |
| 21 | **Auto-Unseal** | Transit seal as KMS, no manual unseal keys, restart test | [→](docs/level21-auto-unseal/) |

### Kubernetes Integration

| Level | Topic | Description | Doc |
|---|---|---|---|
| 23 | **Vault Secrets Operator** | CRDs, VaultStaticSecret, auto-sync to k8s Secrets, hot-reload | [→](docs/level23-vault-secrets-operator/) |

### Monitoring

| Level | Topic | Description | Doc |
|---|---|---|---|
| 22 | **Prometheus + Grafana** | Metrics endpoint, scrape config, key metrics, dashboards | [→](docs/level22-prometheus-grafana/) |

---

## Key Concepts Reference

| Term | Definition |
|---|---|
| **Secret** | Any sensitive key-value data stored in Vault |
| **Engine** | A plugin that provides a feature (KV, PKI, Transit, Database, …) |
| **Mount** | A path where an engine is activated (`secret/`, `pki/`, …) |
| **Policy** | HCL document defining what paths a token can access |
| **Token** | Credential used to authenticate API calls — has TTL and policies |
| **Lease** | Time-bound grant for a secret — can be renewed or revoked |
| **Entity** | Vault's internal identity for a person or service |
| **Alias** | Link between an entity and an auth method account |
| **Group** | Collection of entities sharing policies |
| **Seal/Unseal** | Vault's lock state — sealed Vault refuses all requests |
| **Raft** | Built-in consensus storage for HA — no Consul needed |
| **Shamir** | Default unseal method — N keys, threshold T required |
| **Transit Seal** | Auto-unseal using another Vault's Transit engine as KMS |

---

## API Cheatsheet

```bash
# Set environment
export VAULT_ADDR="https://vault.lab.mecan.ir"
export VAULT_TOKEN="myroot"

# KV — write / read
curl -X POST $VAULT_ADDR/v1/secret/data/myapp/db \
  -H "X-Vault-Token: $VAULT_TOKEN" \
  -d '{"data":{"password":"secret"}}'

curl $VAULT_ADDR/v1/secret/data/myapp/db \
  -H "X-Vault-Token: $VAULT_TOKEN"

# Token — create scoped token
curl -X POST $VAULT_ADDR/v1/auth/token/create \
  -H "X-Vault-Token: $VAULT_TOKEN" \
  -d '{"policies":["my-policy"],"ttl":"1h"}'

# AppRole — login
curl -X POST $VAULT_ADDR/v1/auth/approle/login \
  -d '{"role_id":"...","secret_id":"..."}'

# Userpass — login
curl -X POST $VAULT_ADDR/v1/auth/userpass/login/alice \
  -d '{"password":"alice123"}'

# Dynamic DB — generate credentials
curl $VAULT_ADDR/v1/database/creds/app-role \
  -H "X-Vault-Token: $VAULT_TOKEN"

# Transit — encrypt
echo -n "secret" | base64 | xargs -I{} curl -X POST \
  $VAULT_ADDR/v1/transit/encrypt/myapp-key \
  -H "X-Vault-Token: $VAULT_TOKEN" \
  -d "{\"plaintext\":\"{}\"}"

# Raft snapshot
curl $VAULT_ADDR/v1/sys/storage/raft/snapshot \
  -H "X-Vault-Token: $VAULT_TOKEN" \
  -o vault-snapshot.snap

# Metrics (Prometheus)
curl "$VAULT_ADDR/v1/sys/metrics?format=prometheus" \
  -H "X-Vault-Token: $VAULT_TOKEN"
```

---

## Services at a Glance

| URL | Service | Level | Credentials |
|---|---|---|---|
| `https://vault.lab.mecan.ir` | Vault UI | `level00-setup` | token: `myroot` |
| `http://localhost:8200` | Vault API (direct) | `level00-setup` | token: `myroot` |
| `http://localhost:8210` | Vault HA node-1 | `level15-ha-raft-persistence` | see `vault-ha-init.json` |
| `http://localhost:8220` | Vault HA node-2 | `level15-ha-raft-persistence` | — |
| `http://localhost:8230` | Vault HA node-3 | `level15-ha-raft-persistence` | — |
| `http://localhost:8080` | Keycloak Admin | `level14-keycloak-oidc` | `admin` / `admin` |
| `http://localhost:15672` | RabbitMQ Management | `level16-rabbitmq-redis-dynamic-secrets` | `vaultadmin` / `vaultadmin-pass` |
| `localhost:5432` | PostgreSQL | `level07-dynamic-secrets-db` | `vaultadmin` / `vaultadmin-pass` |
| `localhost:6379` | Redis | `level16-rabbitmq-redis-dynamic-secrets` | password: `vaultadmin-pass` |
| `localhost:2222` | SSH (cert auth) | `level09-ssh-secrets-engine` | Vault-signed cert |
| `localhost:2223` | SSH (OTP) | `level09-ssh-secrets-engine` | Vault OTP |
