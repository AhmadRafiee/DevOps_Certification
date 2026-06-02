#!/usr/bin/env bash
# After applying 02-k8s-rbac.yaml, update Vault's Kubernetes auth config
# with the vault-auth ServiceAccount token so Vault can call the K8s
# TokenReview API to validate pod service account tokens.
#
# Why needed: K8s 1.21+ uses projected tokens with non-standard audiences.
# Providing token_reviewer_jwt lets Vault use TokenReview (server-side
# validation) instead of OIDC/JWKS (client-side signature check).

set -euo pipefail

VAULT_ADDR="${VAULT_ADDR:-http://172.18.0.2:8200}"
VAULT_TOKEN="${VAULT_TOKEN:-myroot}"
K8S_API="https://172.20.0.2:6443"
CONTEXT="${KUBE_CONTEXT:-kind-vault-lab}"

echo "==> Waiting for vault-auth-token Secret to be populated..."
until kubectl get secret vault-auth-token -n default --context="$CONTEXT" \
    -o jsonpath='{.data.token}' 2>/dev/null | grep -q .; do
    sleep 2
done

echo "==> Fetching vault-auth ServiceAccount token..."
REVIEWER_JWT=$(kubectl get secret vault-auth-token -n default --context="$CONTEXT" \
    -o jsonpath='{.data.token}' | base64 -d)

echo "==> Fetching K8s CA certificate..."
K8S_CA=$(kubectl config view \
    --context="$CONTEXT" \
    --raw \
    -o jsonpath='{.clusters[?(@.name=="'"$CONTEXT"'")].cluster.certificate-authority-data}' \
    | base64 -d)

echo "==> Updating Vault Kubernetes auth config with token_reviewer_jwt..."
curl -sf -X POST "$VAULT_ADDR/v1/auth/kubernetes/config" \
    -H "X-Vault-Token: $VAULT_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"kubernetes_host\": \"$K8S_API\",
        \"kubernetes_ca_cert\": $(echo "$K8S_CA" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))'),
        \"token_reviewer_jwt\": \"$REVIEWER_JWT\",
        \"disable_iss_validation\": true
    }" >/dev/null

echo ""
echo "==> Verifying config (token_reviewer_jwt_set should be true)..."
curl -sf "$VAULT_ADDR/v1/auth/kubernetes/config" \
    -H "X-Vault-Token: $VAULT_TOKEN" | python3 -c "
import sys, json
d = json.load(sys.stdin)['data']
print(f'  kubernetes_host        : {d[\"kubernetes_host\"]}')
print(f'  token_reviewer_jwt_set : {d[\"token_reviewer_jwt_set\"]}')
print(f'  disable_iss_validation : {d[\"disable_iss_validation\"]}')
"

echo ""
echo "==> Done. Vault can now validate K8s ServiceAccount tokens."
echo "    Next step: bash vault-agent-injector/install.sh"
