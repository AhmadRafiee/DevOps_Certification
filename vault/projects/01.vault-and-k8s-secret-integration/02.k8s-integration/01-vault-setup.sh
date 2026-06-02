#!/usr/bin/env bash
# Configure Vault for Kubernetes integration via REST API (no local vault CLI required):
#   - Enable KV v2 secrets engine
#   - Enable Kubernetes auth method
#   - Create policies for workloads
#   - Enable Transit engine (encryption-as-a-service)
#   - Seed sample secrets

set -euo pipefail

VAULT_ADDR="${VAULT_ADDR:-http://172.18.0.2:8200}"
VAULT_TOKEN="${VAULT_TOKEN:-myroot}"
K8S_API="https://172.20.0.2:6443"
CONTEXT="${KUBE_CONTEXT:-kind-vault-lab}"

# Thin wrapper: calls local vault CLI if present, otherwise uses the REST API via curl
vapi() {
    local method="$1"; local path="$2"; shift 2
    curl -sf -X "$method" "$VAULT_ADDR/v1/$path" \
        -H "X-Vault-Token: $VAULT_TOKEN" \
        -H "Content-Type: application/json" \
        "$@" | python3 -m json.tool 2>/dev/null || true
}

vapi_put() {
    local path="$1"; shift
    curl -sf -X POST "$VAULT_ADDR/v1/$path" \
        -H "X-Vault-Token: $VAULT_TOKEN" \
        -H "Content-Type: application/json" \
        "$@"
}

echo "==> Checking Vault connectivity..."
curl -sf "$VAULT_ADDR/v1/sys/health" | python3 -m json.tool

# ── 1. KV v2 secrets engine ───────────────────────────────────────────────────
echo ""
echo "==> Enabling KV v2 at secret/"
curl -sf -X POST "$VAULT_ADDR/v1/sys/mounts/secret" \
    -H "X-Vault-Token: $VAULT_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"type":"kv","options":{"version":"2"}}' >/dev/null 2>&1 \
    && echo "    Enabled" || echo "    (already enabled)"

# ── 2. Transit engine ─────────────────────────────────────────────────────────
echo ""
echo "==> Enabling Transit engine at transit/"
curl -sf -X POST "$VAULT_ADDR/v1/sys/mounts/transit" \
    -H "X-Vault-Token: $VAULT_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"type":"transit"}' >/dev/null 2>&1 \
    && echo "    Enabled" || echo "    (already enabled)"

echo "    Creating encryption key 'k8s-secrets' (aes256-gcm96)..."
curl -sf -X POST "$VAULT_ADDR/v1/transit/keys/k8s-secrets" \
    -H "X-Vault-Token: $VAULT_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"type":"aes256-gcm96"}' >/dev/null 2>&1 \
    && echo "    Key created" || echo "    (key already exists)"

# ── 3. Kubernetes auth method ─────────────────────────────────────────────────
echo ""
echo "==> Enabling Kubernetes auth method..."
curl -sf -X POST "$VAULT_ADDR/v1/sys/auth/kubernetes" \
    -H "X-Vault-Token: $VAULT_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"type":"kubernetes"}' >/dev/null 2>&1 \
    && echo "    Enabled" || echo "    (already enabled)"

echo "    Fetching K8s CA certificate from kubeconfig..."
K8S_CA=$(kubectl config view \
    --context="$CONTEXT" \
    --raw \
    -o jsonpath='{.clusters[?(@.name=="'"$CONTEXT"'")].cluster.certificate-authority-data}' \
    | base64 -d)

echo "    Configuring Kubernetes auth backend -> $K8S_API"
curl -sf -X POST "$VAULT_ADDR/v1/auth/kubernetes/config" \
    -H "X-Vault-Token: $VAULT_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"kubernetes_host\": \"$K8S_API\",
        \"kubernetes_ca_cert\": $(echo "$K8S_CA" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))'),
        \"disable_iss_validation\": true
    }" >/dev/null
echo "    Done"

# ── 4. Policies ───────────────────────────────────────────────────────────────
echo ""
echo "==> Creating Vault policies..."

# myapp-policy: read KV secrets + use Transit
MYAPP_POLICY='path "secret/data/myapp/*" { capabilities = ["read","list"] }
path "transit/encrypt/k8s-secrets" { capabilities = ["update"] }
path "transit/decrypt/k8s-secrets" { capabilities = ["update"] }'

curl -sf -X PUT "$VAULT_ADDR/v1/sys/policies/acl/myapp-policy" \
    -H "X-Vault-Token: $VAULT_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"policy\": $(echo "$MYAPP_POLICY" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')}" >/dev/null
echo "    Created: myapp-policy"

# db-policy: read DB secrets
DB_POLICY='path "secret/data/db/*" { capabilities = ["read"] }'

curl -sf -X PUT "$VAULT_ADDR/v1/sys/policies/acl/db-policy" \
    -H "X-Vault-Token: $VAULT_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"policy\": $(echo "$DB_POLICY" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')}" >/dev/null
echo "    Created: db-policy"

# ── 5. Kubernetes auth roles ──────────────────────────────────────────────────
echo ""
echo "==> Creating Kubernetes auth roles..."

curl -sf -X POST "$VAULT_ADDR/v1/auth/kubernetes/role/myapp" \
    -H "X-Vault-Token: $VAULT_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "bound_service_account_names": ["myapp-sa"],
        "bound_service_account_namespaces": ["default"],
        "policies": ["myapp-policy"],
        "ttl": "1h"
    }' >/dev/null
echo "    Created role: myapp -> SA myapp-sa/default -> myapp-policy"

curl -sf -X POST "$VAULT_ADDR/v1/auth/kubernetes/role/db-app" \
    -H "X-Vault-Token: $VAULT_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "bound_service_account_names": ["db-sa"],
        "bound_service_account_namespaces": ["default"],
        "policies": ["db-policy"],
        "ttl": "1h"
    }' >/dev/null
echo "    Created role: db-app -> SA db-sa/default -> db-policy"

# ── 6. Sample secrets ─────────────────────────────────────────────────────────
echo ""
echo "==> Writing sample secrets to Vault..."

API_KEY="s3cr3t-api-key-$(openssl rand -hex 8)"
DB_PASS=$(openssl rand -base64 16)
PG_PASS=$(openssl rand -base64 16)
REPL_PASS=$(openssl rand -base64 16)

curl -sf -X POST "$VAULT_ADDR/v1/secret/data/myapp/config" \
    -H "X-Vault-Token: $VAULT_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"data\":{\"API_KEY\":\"$API_KEY\",\"APP_ENV\":\"production\",\"LOG_LEVEL\":\"info\"}}" >/dev/null
echo "    Written: secret/myapp/config"

curl -sf -X POST "$VAULT_ADDR/v1/secret/data/myapp/database" \
    -H "X-Vault-Token: $VAULT_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"data\":{
        \"DB_HOST\":\"postgres.default.svc.cluster.local\",
        \"DB_PORT\":\"5432\",
        \"DB_NAME\":\"myapp\",
        \"DB_USER\":\"appuser\",
        \"DB_PASSWORD\":\"$DB_PASS\"
    }}" >/dev/null
echo "    Written: secret/myapp/database"

curl -sf -X POST "$VAULT_ADDR/v1/secret/data/db/credentials" \
    -H "X-Vault-Token: $VAULT_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"data\":{\"POSTGRES_PASSWORD\":\"$PG_PASS\",\"REPLICATION_PASSWORD\":\"$REPL_PASS\"}}" >/dev/null
echo "    Written: secret/db/credentials"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║         Vault Kubernetes Integration — Configured!           ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Vault Address : $VAULT_ADDR"
echo "║  K8s API       : $K8S_API"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Secrets Engines:  secret/ (KV v2)  |  transit/              ║"
echo "║  Encryption Key :  k8s-secrets (AES-256-GCM)                 ║"
echo "║  Auth Methods   :  kubernetes/                               ║"
echo "║  Policies       :  myapp-policy  |  db-policy                ║"
echo "║  K8s Roles      :  myapp  |  db-app                          ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Next steps:                                                 ║"
echo "║  1. kubectl apply -f 02-k8s-rbac.yaml                        ║"
echo "║  2. bash vault-agent-injector/install.sh                     ║"
echo "║  3. kubectl apply -f test-workload/                          ║"
echo "╚══════════════════════════════════════════════════════════════╝"
