# Level 1 — Kubernetes + Vault Integration

Integrate HashiCorp Vault with a Kubernetes cluster so that:
- Pods **never receive secrets via environment variables or ConfigMaps**
- Secrets are **fetched at runtime** from Vault using the pod's ServiceAccount identity
- All secret data is **encrypted at rest** inside Vault (AES-256-GCM)
- The **encryption key never leaves Vault** (Transit engine)

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│  Kubernetes Cluster (kind-vault-lab)                                │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │  vault namespace                                             │   │
│  │  ┌─────────────────────────────────────────────────────┐    │   │
│  │  │  vault-agent-injector  (MutatingWebhookConfiguration)│    │   │
│  │  └───────────────────────┬─────────────────────────────┘    │   │
│  └──────────────────────────│─────────────────────────────────-┘   │
│                             │ intercepts pod creation               │
│  ┌──────────────────────────▼─────────────────────────────────┐    │
│  │  default namespace                                          │    │
│  │                                                             │    │
│  │  Pod: myapp                                                 │    │
│  │  ┌──────────────┐  ┌────────────────┐  ┌────────────────┐  │    │
│  │  │ init-container│  │  vault-agent   │  │  app container │  │    │
│  │  │ (vault-agent) │  │  (sidecar)     │  │  (your app)    │  │    │
│  │  │               │  │                │  │                │  │    │
│  │  │ 1. Auth to    │  │ Renews secrets │  │ Reads from     │  │    │
│  │  │    Vault with │  │ periodically   │  │ /vault/secrets/│  │    │
│  │  │    SA token   │  │                │  │ (tmpfs)        │  │    │
│  │  │ 2. Write      │  │                │  │                │  │    │
│  │  │    secrets to │  │                │  │                │  │    │
│  │  │    /vault/    │  │                │  │                │  │    │
│  │  │    secrets/   │  │                │  │                │  │    │
│  │  └──────────────┘  └────────────────┘  └────────────────┘  │    │
│  └──────────────────────────────────────────────────────────────┘   │
└──────────────────────────────┬──────────────────────────────────────┘
                               │ app_net (172.18.0.0/16)
          ┌────────────────────▼────────────────────┐
          │  hashicorp_vault  (Docker container)     │
          │  172.18.0.2:8200                         │
          │                                          │
          │  ┌──────────────┐  ┌──────────────────┐  │
          │  │  KV v2       │  │  Transit Engine  │  │
          │  │  secret/     │  │  transit/        │  │
          │  │  (encrypted  │  │  (AES-256-GCM    │  │
          │  │   at rest)   │  │   encrypt/       │  │
          │  └──────────────┘  │   decrypt API)   │  │
          │                    └──────────────────┘  │
          │  ┌──────────────────────────────────────┐ │
          │  │  Kubernetes Auth Method              │ │
          │  │  Validates pod SA tokens via         │ │
          │  │  K8s TokenReview API                 │ │
          │  └──────────────────────────────────────┘ │
          └───────────────────────────────────────────┘
```

---

## Network Map

| Component          | Network  | IP             | Port  |
|--------------------|----------|----------------|-------|
| Vault              | app_net  | 172.18.0.2     | 8200  |
| K8s control-plane  | app_net  | 172.18.0.3     | —     |
| K8s control-plane  | kind     | 172.20.0.2     | 6443  |
| K8s worker         | kind     | 172.20.0.3     | —     |

Pods inside K8s can reach Vault at `http://172.18.0.2:8200` through the node's routing.

---

## Authentication Flow

```
Pod SA Token (JWT)
      │
      ▼
Vault /auth/kubernetes/login
      │
      ├─► Vault calls K8s TokenReview API (https://172.20.0.2:6443)
      │          to verify the token is genuine
      │
      ├─► Vault checks: does the SA name/namespace match a bound role?
      │
      └─► Yes → issues a short-lived Vault token (TTL: 1h)
                    │
                    └─► Pod uses Vault token to read secrets
```

---

## Step-by-Step Setup

### Step 1 — Configure Vault

```bash
cd level01-k8s-integration
chmod +x 01-vault-setup.sh
bash 01-vault-setup.sh
```

This script (uses REST API, no local vault CLI required):
- Enables **KV v2** at `secret/` — secrets encrypted at rest (AES-256-GCM)
- Enables **Transit engine** at `transit/` — encryption-as-a-service
- Creates encryption key `k8s-secrets`
- Enables **Kubernetes auth method** and points it at the K8s API
- Creates policies `myapp-policy` and `db-policy`
- Creates Kubernetes auth roles binding ServiceAccounts to policies
- Seeds sample secrets

### Step 2 — Apply K8s RBAC

```bash
kubectl apply -f 02-k8s-rbac.yaml --context kind-vault-lab
```

Creates:
- `vault-auth` ServiceAccount + long-lived token Secret (for TokenReview API)
- `myapp-sa` ServiceAccount (what the demo app runs as)
- `db-sa` ServiceAccount (for DB workloads)

### Step 3 — Update Vault with Token Reviewer

```bash
chmod +x 03-vault-token-reviewer.sh
bash 03-vault-token-reviewer.sh
```

K8s 1.21+ uses projected tokens with non-standard audiences. This script fetches the
`vault-auth` long-lived token and tells Vault to use K8s **TokenReview API** for
validation (server-side) instead of OIDC JWKS (client-side). Without this step,
Vault returns `permission denied` for all pod logins.

### Step 4 — Install Vault Agent Injector

```bash
chmod +x vault-agent-injector/install.sh
bash vault-agent-injector/install.sh
```

Downloads vault-helm chart from GitHub (v0.29.0) and installs with
`server.enabled=false` — only the MutatingWebhookConfiguration + injector
deployment are created.

Verify:
```bash
kubectl get pods -n vault --context kind-vault-lab
kubectl get mutatingwebhookconfigurations --context kind-vault-lab
```

### Step 5 — Deploy Test Workload

```bash
kubectl apply -f test-workload/ --context kind-vault-lab
```

Watch the pod come up (it will have 3 containers: init + sidecar + app):
```bash
kubectl get pods --context kind-vault-lab -w
kubectl describe pod -l app=myapp --context kind-vault-lab
```

Read the injected secrets from the app container:
```bash
kubectl exec -it deploy/myapp --context kind-vault-lab -- cat /vault/secrets/config
kubectl exec -it deploy/myapp --context kind-vault-lab -- cat /vault/secrets/database
```

### Step 5 — Transit Engine Demo

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

---

## Secret Injection Annotations

| Annotation | Purpose |
|---|---|
| `vault.hashicorp.com/agent-inject: "true"` | Enable injection for this pod |
| `vault.hashicorp.com/role: "<role>"` | Vault Kubernetes auth role to use |
| `vault.hashicorp.com/agent-inject-secret-<name>: "<path>"` | Inject secret at `/vault/secrets/<name>` |
| `vault.hashicorp.com/agent-inject-template-<name>: \|` | Custom Go template for the secret file |
| `vault.hashicorp.com/agent-inject-token: "true"` | Also inject the Vault token at `/vault/secrets/token` |

---

## Verifying Secrets are Encrypted

Secrets stored in Vault are encrypted at rest with AES-256-GCM. You can confirm the raw storage never contains plaintext:

```bash
# Read the raw KV secret (metadata only — data is encrypted in Vault's storage)
curl -s http://172.18.0.2:8200/v1/secret/metadata/myapp/config \
  -H "X-Vault-Token: myroot" | python3 -m json.tool

# Read the actual secret (Vault decrypts it in-memory before returning)
curl -s http://172.18.0.2:8200/v1/secret/data/myapp/config \
  -H "X-Vault-Token: myroot" | python3 -m json.tool
```

---

## Troubleshooting

**Injector not mutating pods:**
```bash
kubectl get mutatingwebhookconfigurations --context kind-vault-lab
# Must show vault-injector-vault-agent-injector
```

**Pod stuck in Init state:**
```bash
kubectl logs <pod-name> -c vault-agent-init --context kind-vault-lab
# Look for: "Error authenticating" or "permission denied"
```

**Vault can't reach K8s API:**
```bash
docker exec hashicorp_vault curl -sk https://172.20.0.2:6443/healthz
# Must return: ok
```

**Check Vault token for a running pod:**
```bash
kubectl exec deploy/myapp --context kind-vault-lab -- \
  sh -c 'cat /var/run/secrets/kubernetes.io/serviceaccount/token' | cut -d. -f2 | base64 -d
```

---

## Files

```
level01-k8s-integration/
├── 01-vault-setup.sh                  ← Step 1: Configure Vault via REST API
├── 02-k8s-rbac.yaml                   ← Step 2: ServiceAccounts + RBAC + reviewer token
├── 03-vault-token-reviewer.sh         ← Step 3: Give Vault the K8s reviewer token
├── vault-agent-injector/
│   ├── helm-values.yaml               ← Helm chart overrides (injector-only, external Vault)
│   └── install.sh                     ← Step 4: Install injector via Helm
└── test-workload/
    ├── 01-serviceaccount.yaml         ← App ServiceAccount
    ├── 02-deployment.yaml             ← Demo app with Vault annotations
    └── 03-transit-demo.yaml           ← Transit engine: encrypt/decrypt demo
```
