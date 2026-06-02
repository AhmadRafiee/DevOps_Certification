# Vault Lab — Kubernetes Secrets Management

A hands-on lab that demonstrates how to integrate HashiCorp Vault with Kubernetes
so that pods **never receive secrets via environment variables or ConfigMaps**.
Secrets are fetched at runtime using each pod's own identity, and the encryption
key never leaves Vault.

---

## What Problem Does This Solve?

| Traditional Approach | This Lab |
|---|---|
| Secrets baked into `env:` or ConfigMaps | Secrets fetched from Vault at pod startup |
| Secrets visible in `kubectl describe pod` | Secrets written to an in-memory tmpfs volume |
| One leaked token = full secret exposure | Short-lived Vault tokens per pod (TTL: 1h) |
| No audit trail | Every secret read is logged in Vault |
| Encryption key lives in the app | Key stays in Vault — only ciphertext crosses the wire |

---

## Repository Layout

```
vault/
├── README.md                        ← you are here
├── 01.setup/
│   ├── compose.yml                  ← Vault Docker Compose stack
│   ├── kind-vault-lab.yaml          ← Kubernetes cluster definition (kind)
│   └── README.md                    ← Run Vault with Docker Compose
└── 02.k8s-integration/
    ├── README.md                    ← Detailed level docs
    ├── 01-vault-setup.sh            ← Step 1: configure Vault engines, policies, secrets
    ├── 02-k8s-rbac.yaml             ← Step 2: ServiceAccounts + RBAC + reviewer token
    ├── 03-vault-token-reviewer.sh   ← Step 3: give Vault the K8s TokenReview token
    ├── vault-agent-injector/
    │   ├── helm-values.yaml         ← Helm overrides (injector-only, external Vault)
    │   └── install.sh               ← Step 4: install Vault Agent Injector via Helm
    └── test-workload/
        ├── 01-serviceaccount.yaml   ← App ServiceAccount
        ├── 02-deployment.yaml       ← Demo app with Vault annotations
        └── 03-transit-demo.yaml     ← Transit engine: encrypt/decrypt demo
```

---

## Architecture

```
Kubernetes Cluster (kind-vault-lab)
┌───────────────────────────────────────────────────────────────────┐
│                                                                   │
│  vault namespace                                                  │
│  ┌────────────────────────────────────────────────────────────┐   │
│  │  vault-agent-injector  (MutatingWebhookConfiguration)      │   │
│  └──────────────────────────┬─────────────────────────────────┘   │
│                             │ intercepts every annotated pod      │
│  default namespace          │                                     │
│  ┌──────────────────────────▼─────────────────────────────────┐   │
│  │  Pod: myapp                                                 │   │
│  │  ┌──────────────┐   ┌────────────────┐   ┌──────────────┐  │   │
│  │  │ init-container│   │ vault-agent    │   │ app          │  │   │
│  │  │ (vault-agent) │   │ (sidecar)      │   │ container    │  │   │
│  │  │               │   │                │   │              │  │   │
│  │  │ 1. Auth with  │   │ Renews secrets │   │ Reads files  │  │   │
│  │  │    SA token   │   │ periodically   │   │ from         │  │   │
│  │  │ 2. Write to   │   │                │   │ /vault/      │  │   │
│  │  │    /vault/    │   │                │   │ secrets/     │  │   │
│  │  │    secrets/   │   │                │   │ (tmpfs)      │  │   │
│  │  └──────────────┘   └────────────────┘   └──────────────┘  │   │
│  └─────────────────────────────────────────────────────────────┘   │
└──────────────────────────────┬────────────────────────────────────┘
                               │ Docker network: app_net (172.18.0.0/16)
          ┌────────────────────▼────────────────────┐
          │  hashicorp_vault  (Docker container)     │
          │  172.18.0.2:8200                         │
          │                                          │
          │  ┌──────────────┐  ┌──────────────────┐  │
          │  │  KV v2       │  │  Transit Engine  │  │
          │  │  secret/     │  │  AES-256-GCM     │  │
          │  │  (encrypted  │  │  encrypt/decrypt │  │
          │  │   at rest)   │  │  API             │  │
          │  └──────────────┘  └──────────────────┘  │
          │  ┌──────────────────────────────────────┐ │
          │  │  Kubernetes Auth Method              │ │
          │  │  validates pod SA tokens via         │ │
          │  │  K8s TokenReview API                 │ │
          │  └──────────────────────────────────────┘ │
          └───────────────────────────────────────────┘
```

### Network Map

| Component         | Network | IP           | Port |
|-------------------|---------|--------------|------|
| Vault             | app_net | 172.18.0.2   | 8200 |
| K8s control-plane | app_net | 172.18.0.3   | —    |
| K8s control-plane | kind    | 172.20.0.2   | 6443 |
| K8s worker        | kind    | 172.20.0.3   | —    |

Pods inside the cluster reach Vault at `http://172.18.0.2:8200` through the node's
routing table — no NodePort or LoadBalancer needed.

---

## Authentication Flow

Every secret fetch goes through this chain:

```
Pod SA Token (JWT auto-mounted by Kubernetes)
      │
      ▼
vault-agent → POST /auth/kubernetes/login  (to Vault)
      │
      ├─► Vault calls K8s TokenReview API (https://172.20.0.2:6443)
      │         verifies the token is genuine and not expired
      │
      ├─► Vault checks: does this SA name + namespace match a bound role?
      │
      └─► Match → issues a short-lived Vault token (TTL: 1h)
                       │
                       └─► vault-agent uses Vault token to read secrets
                               and writes them to /vault/secrets/ (tmpfs)
```

No secret ever appears in a pod's environment or Kubernetes object.

---

## How to Implement — Step by Step

### Prerequisites

```bash
# Tools required on your workstation
docker          # to run Vault
kind            # to create the local K8s cluster
kubectl         # to manage the cluster
helm            # to install the Vault Agent Injector
curl + python3  # used by the setup scripts (no vault CLI needed)
```

---

### Phase 0 — Start Vault and the Kubernetes Cluster

**Start Vault:**

```bash
cd 01.setup
docker compose up -d
# Vault listens on http://172.18.0.2:8200  root token: myroot
```

**Create the kind cluster and connect both networks:**

```bash
# kind-vault-lab.yaml is inside 01.setup/ — run from there
kind create cluster --config kind-vault-lab.yaml --image kindest/node:v1.29.2

# Connect K8s nodes to the same Docker network as Vault
docker network connect app_net vault-lab-control-plane
docker network connect app_net vault-lab-worker

# Connect Vault to the kind network so Vault can call the K8s API
docker network connect kind hashicorp_vault
```

Verify connectivity (Vault → K8s API):

```bash
docker exec hashicorp_vault curl -sk https://172.20.0.2:6443/healthz
# Expected: ok
```

---

### Phase 1 — Configure Vault (Step 1)

```bash
cd ../02.k8s-integration
bash 01-vault-setup.sh
```

What this script does via the Vault REST API:

| Action | Result |
|---|---|
| Enable KV v2 at `secret/` | Secrets stored encrypted (AES-256-GCM) at rest |
| Enable Transit engine at `transit/` | Encryption-as-a-service API |
| Create key `k8s-secrets` | AES-256-GCM key that never leaves Vault |
| Enable Kubernetes auth method | Vault can validate pod SA tokens |
| Point auth method at K8s API | `https://172.20.0.2:6443` |
| Create `myapp-policy` | read `secret/data/myapp/*` + use Transit |
| Create `db-policy` | read `secret/data/db/*` |
| Create K8s role `myapp` | binds SA `myapp-sa/default` → `myapp-policy` |
| Create K8s role `db-app` | binds SA `db-sa/default` → `db-policy` |
| Seed sample secrets | `secret/myapp/config`, `secret/myapp/database` |

---

### Phase 2 — Create Kubernetes ServiceAccounts (Step 2)

```bash
kubectl apply -f 02-k8s-rbac.yaml --context kind-vault-lab
```

Creates three ServiceAccounts:

| ServiceAccount | Purpose |
|---|---|
| `vault-auth` | Holds a long-lived token Vault uses to call TokenReview API |
| `myapp-sa` | The demo app runs as this SA — bound to `myapp-policy` in Vault |
| `db-sa` | DB workloads run as this SA — bound to `db-policy` in Vault |

---

### Phase 3 — Give Vault the Token Reviewer Credential (Step 3)

```bash
bash 03-vault-token-reviewer.sh
```

**Why this step is mandatory:** Kubernetes 1.21+ issues projected ServiceAccount tokens
with a non-standard audience (`kubernetes.default.svc`). Vault cannot verify these tokens
by downloading the cluster's JWKS — the signature check would fail. Instead, Vault must
forward the token to the K8s TokenReview API for server-side validation.

This script extracts the long-lived `vault-auth` token from the Secret and sends it to
Vault so that Vault can authenticate its own TokenReview calls. Without this step, every
pod login returns `permission denied`.

---

### Phase 4 — Install the Vault Agent Injector (Step 4)

```bash
bash vault-agent-injector/install.sh
```

Installs the Vault Helm chart with `server.enabled=false` — only the injector is deployed.
The injector registers a `MutatingWebhookConfiguration` that intercepts every pod creation
in the cluster and rewrites the pod spec to add:

- An **init-container** (`vault-agent-init`) that authenticates to Vault and populates
  `/vault/secrets/` before the app container starts.
- A **sidecar** (`vault-agent`) that keeps secrets refreshed for the pod's lifetime.

Verify installation:

```bash
kubectl get pods -n vault --context kind-vault-lab
kubectl get mutatingwebhookconfigurations --context kind-vault-lab
# Must show: vault-injector-vault-agent-injector
```

---

### Phase 5 — Deploy the Test Application (Step 5)

```bash
kubectl apply -f test-workload/ --context kind-vault-lab
```

Watch the pod start (it will have 3 containers: init + sidecar + app):

```bash
kubectl get pods --context kind-vault-lab -w
```

Read the injected secrets:

```bash
kubectl exec -it deploy/myapp --context kind-vault-lab -- cat /vault/secrets/config
kubectl exec -it deploy/myapp --context kind-vault-lab -- cat /vault/secrets/database
```

Expected output for `/vault/secrets/config`:

```
API_KEY=s3cr3t-api-key-...
APP_ENV=production
LOG_LEVEL=info
```

---

### Phase 6 — Transit Engine Demo (Encryption-as-a-Service)

```bash
kubectl apply -f test-workload/03-transit-demo.yaml --context kind-vault-lab
kubectl logs transit-demo -c transit-demo --context kind-vault-lab -f
```

Expected output:

```
==> Encrypting 'super-secret-data' with Transit key k8s-secrets...
    Ciphertext: vault:v1:AAAAAA...
==> Decrypting ciphertext...
    Decrypted : super-secret-data
==> Transit demo complete. Key never left Vault.
```

The encryption key `k8s-secrets` exists only inside Vault. The application sends plaintext
to Vault and receives ciphertext back — the key is never exported.

---

## Secret Injection Annotations

Add these annotations to any pod's `metadata.annotations` to enable injection:

```yaml
annotations:
  # Required: enable the injector for this pod
  vault.hashicorp.com/agent-inject: "true"

  # The Vault Kubernetes auth role to authenticate as
  vault.hashicorp.com/role: "myapp"

  # Inject a secret — written to /vault/secrets/<name>
  vault.hashicorp.com/agent-inject-secret-config: "secret/data/myapp/config"

  # Optional: Go template to control the output format
  vault.hashicorp.com/agent-inject-template-config: |
    {{- with secret "secret/data/myapp/config" -}}
    API_KEY={{ .Data.data.API_KEY }}
    APP_ENV={{ .Data.data.APP_ENV }}
    {{- end }}
```

The injector reads these annotations, mutates the pod spec, and adds the Vault agent
containers automatically — no changes to your application image are needed.

---

## Verifying Encryption at Rest

Secrets in Vault's KV v2 engine are encrypted with AES-256-GCM before being written to
storage. You can confirm the raw storage backend never contains plaintext:

```bash
# Metadata only — no secret values
curl -s http://172.18.0.2:8200/v1/secret/metadata/myapp/config \
  -H "X-Vault-Token: myroot" | python3 -m json.tool

# Vault decrypts in-memory and returns the plaintext over TLS
curl -s http://172.18.0.2:8200/v1/secret/data/myapp/config \
  -H "X-Vault-Token: myroot" | python3 -m json.tool
```

---

## Troubleshooting

**Injector not mutating pods:**

```bash
kubectl get mutatingwebhookconfigurations --context kind-vault-lab
# Must show: vault-injector-vault-agent-injector
```

**Pod stuck in Init state:**

```bash
kubectl logs <pod-name> -c vault-agent-init --context kind-vault-lab
# Look for: "Error authenticating" or "permission denied"
# Usually means Step 3 (token-reviewer) was skipped
```

**Vault cannot reach K8s API:**

```bash
docker exec hashicorp_vault curl -sk https://172.20.0.2:6443/healthz
# Must return: ok
# If not: re-run `docker network connect kind hashicorp_vault`
```

**Inspect the SA token a pod is using:**

```bash
kubectl exec deploy/myapp --context kind-vault-lab -- \
  sh -c 'cat /var/run/secrets/kubernetes.io/serviceaccount/token' \
  | cut -d. -f2 | base64 -d
# Decodes the JWT payload — shows namespace, SA name, expiry
```

---

## Key Concepts

| Term | Meaning |
|---|---|
| **KV v2** | Versioned key-value secrets engine; data encrypted at rest |
| **Transit Engine** | Encryption-as-a-service; keys never leave Vault |
| **Kubernetes Auth** | Auth method that validates pod SA tokens via TokenReview API |
| **SA Token** | JWT auto-mounted into every pod at `/var/run/secrets/kubernetes.io/serviceaccount/token` |
| **TokenReview API** | Kubernetes API that validates whether a JWT token is genuine |
| **Policy** | HCL document that defines which paths a Vault token can access |
| **Role** | Maps a Kubernetes SA to a Vault policy |
| **MutatingWebhook** | Kubernetes admission webhook that rewrites pod specs at creation time |
| **tmpfs** | In-memory filesystem; secrets written here are never flushed to disk |
