# Level 23 — Vault Secrets Operator (Kubernetes)

**Vault Address:** `http://172.19.0.2:8200` (internal, from pods)
**k8s Cluster:** `kind-vault-lab`
**VSO Version:** `0.8.1`

---

## Overview

Vault Secrets Operator (VSO) is a Kubernetes controller that watches custom
resources and automatically syncs Vault secrets into Kubernetes Secrets.
No Vault Agent sidecars, no application code changes — the app just reads
a standard Kubernetes Secret.

```
Developer applies VaultStaticSecret CR
VSO controller watches CR
  └── authenticates to Vault (k8s auth)
  └── reads Vault secret
  └── creates/updates Kubernetes Secret
  └── re-syncs every refreshAfter seconds

App reads Kubernetes Secret → gets Vault-sourced data
Vault secret rotated → VSO auto-updates k8s Secret
```

---

## 23.1 VSO vs Vault Agent

| Property | Vault Agent | VSO |
|---|---|---|
| Runs as | Sidecar container per pod | Single cluster-wide controller |
| Auth | Per pod (AppRole/k8s) | Per VaultAuth CR |
| Secret delivery | File injection | Kubernetes Secret |
| App changes needed | None (reads file) | None (reads k8s Secret) |
| Secret rotation | File re-rendered | k8s Secret auto-updated |
| Overhead | One agent per pod | One controller for all |

---

## 23.2 Install VSO

### Via Helm (recommended)
```bash
helm repo add hashicorp https://helm.releases.hashicorp.com
helm install vault-secrets-operator hashicorp/vault-secrets-operator \
  --namespace vault-secrets-operator-system \
  --create-namespace \
  --set defaultVaultConnection.enabled=true \
  --set defaultVaultConnection.address="http://<vault-ip>:8200"
```

### Manual CRD install (used in this lab — Helm CDN blocked)
```bash
BASE="https://raw.githubusercontent.com/hashicorp/vault-secrets-operator/v0.8.1"

for crd in vaultauths vaultconnections vaultstaticsecrets \
           vaultdynamicsecrets vaultpkisecrets \
           secrettransformations vaultauthglobals hcpauths; do
  kubectl apply -f "$BASE/config/crd/bases/secrets.hashicorp.com_${crd}.yaml"
done
```

---

## 23.3 Vault Setup

### Write secret

```bash
curl -X POST https://vault.lab.mecan.ir/v1/secret/data/vso-test/app-config \
  -H "X-Vault-Token: myroot" \
  -d '{"data":{"DB_HOST":"postgres.svc.cluster.local","DB_PASS":"secret","API_KEY":"key"}}'
```

### Create policy

```bash
curl -X PUT https://vault.lab.mecan.ir/v1/sys/policies/acl/vso-app-policy \
  -H "X-Vault-Token: myroot" \
  -d '{"policy":"path \"secret/data/vso-test/*\" { capabilities = [\"read\"] }"}'
```

### Create k8s auth role

```bash
curl -X POST https://vault.lab.mecan.ir/v1/auth/kubernetes/role/vso-app \
  -H "X-Vault-Token: myroot" \
  -d '{
    "bound_service_account_names": ["vso-app"],
    "bound_service_account_namespaces": ["default"],
    "policies": ["vso-app-policy"],
    "ttl": "1h",
    "audience": "https://kubernetes.default.svc.cluster.local"
  }'
```

---

## 23.4 VSO Custom Resources

### VaultConnection — how to reach Vault

```yaml
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultConnection
metadata:
  name: vault-dev
  namespace: default
spec:
  address: http://172.19.0.2:8200
  skipTLSVerify: true
```

### VaultAuth — how to authenticate

```yaml
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultAuth
metadata:
  name: vso-app-auth
  namespace: default
spec:
  vaultConnectionRef: vault-dev
  method: kubernetes
  mount: kubernetes
  kubernetes:
    role: vso-app
    serviceAccount: vso-app
    audiences:
      - https://kubernetes.default.svc.cluster.local
```

### VaultStaticSecret — sync a KV secret

```yaml
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultStaticSecret
metadata:
  name: app-config
  namespace: default
spec:
  vaultAuthRef: vso-app-auth
  mount: secret
  type: kv-v2
  path: vso-test/app-config
  refreshAfter: 30s         # poll interval for updates
  destination:
    name: app-config-secret  # name of the k8s Secret to create
    create: true
```

---

## 23.5 Result: Kubernetes Secret

After VSO syncs, a standard k8s Secret appears:

```bash
kubectl get secret app-config-secret -n default
# NAME                TYPE     DATA   AGE
# app-config-secret   Opaque   4      13s

kubectl get secret app-config-secret -o jsonpath='{.data.DB_PASS}' | base64 -d
# vso-synced-secret
```

The app reads it like any k8s Secret:

```yaml
env:
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: app-config-secret
        key: DB_PASS
```

---

## 23.6 Hot-Reload Test

When the Vault secret is updated, VSO automatically syncs within `refreshAfter`:

```bash
# Update Vault secret
curl -X POST vault.../v1/secret/data/vso-test/app-config \
  -d '{"data":{"DB_PASS":"rotated-secret-v2","API_KEY":"new-key-v2"}}'

# Within 30s, the k8s Secret is updated automatically
kubectl get secret app-config-secret -o jsonpath='{.data.DB_PASS}' | base64 -d
# rotated-secret-v2
```

---

## 23.7 Test Results

| Test | Result |
|---|---|
| VSO CRDs installed | ✅ 9 CRDs |
| VSO controller running | ✅ |
| VaultConnection created | ✅ |
| VaultAuth with k8s auth | ✅ |
| VaultStaticSecret created | ✅ |
| Kubernetes Secret auto-created from Vault | ✅ |
| Secret values match Vault source | ✅ |
| Vault secret updated → k8s Secret auto-updated within 30s | ✅ |

---

## 23.8 VaultDynamicSecret (bonus)

For dynamic secrets (database credentials), use `VaultDynamicSecret`:

```yaml
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultDynamicSecret
metadata:
  name: db-creds
  namespace: default
spec:
  vaultAuthRef: vso-app-auth
  mount: database
  path: creds/app-role
  destination:
    name: db-credentials
    create: true
  renewalPercent: 67    # renew when 67% of TTL elapsed
```

VSO generates credentials, writes them to `db-credentials` k8s Secret,
and renews them automatically before expiry.

---

## API Reference

| Resource | Kind | Purpose |
|---|---|---|
| `vaultconnections` | VaultConnection | Define Vault server address |
| `vaultauths` | VaultAuth | Define auth method and role |
| `vaultstaticsecrets` | VaultStaticSecret | Sync KV secrets |
| `vaultdynamicsecrets` | VaultDynamicSecret | Sync dynamic secrets |
| `vaultpkisecrets` | VaultPKISecret | Issue PKI certificates |
