#!/usr/bin/env bash
# Install Vault Agent Injector into the K8s cluster using Helm.
# The injector watches for pods with vault.hashicorp.com/* annotations and
# automatically injects an init container + sidecar that fetch secrets from Vault.

set -euo pipefail

NAMESPACE="vault"
CONTEXT="${KUBE_CONTEXT:-kind-vault-lab}"
CHART_DIR="$(cd "$(dirname "$0")" && pwd)"
CHART_CACHE="/tmp/vault-helm-0.29.0"
CHART_VERSION="0.29.0"

# Download chart from GitHub if not cached (hashicorp Helm repo may have network restrictions)
if [ ! -d "$CHART_CACHE" ]; then
    echo "==> Downloading vault-helm chart v$CHART_VERSION from GitHub..."
    curl -fsSL "https://github.com/hashicorp/vault-helm/archive/refs/tags/v$CHART_VERSION.tar.gz" \
        -o /tmp/vault-helm.tar.gz
    tar xzf /tmp/vault-helm.tar.gz -C /tmp/
    rm /tmp/vault-helm.tar.gz
fi

echo ""
echo "==> Creating namespace '$NAMESPACE'..."
kubectl create namespace "$NAMESPACE" \
    --context="$CONTEXT" \
    --dry-run=client -o yaml | kubectl apply -f - --context="$CONTEXT"

echo ""
echo "==> Installing vault-agent-injector..."
helm upgrade --install vault-injector "$CHART_CACHE" \
    --namespace "$NAMESPACE" \
    --kube-context "$CONTEXT" \
    --values "$CHART_DIR/helm-values.yaml"

echo ""
echo "==> Waiting for injector pod to be ready..."
# Delete any stuck old pod during rolling update
kubectl delete pod -n "$NAMESPACE" --context "$CONTEXT" \
    -l app.kubernetes.io/name=vault-agent-injector \
    --field-selector status.phase=Pending 2>/dev/null || true

kubectl rollout status deployment/vault-injector-agent-injector \
    --namespace "$NAMESPACE" \
    --context "$CONTEXT" \
    --timeout=120s

echo ""
echo "==> Vault Agent Injector installed!"
echo ""
echo "    The MutatingWebhookConfiguration is now active."
echo "    Any pod with  vault.hashicorp.com/agent-inject: 'true'  will get"
echo "    secrets injected at /vault/secrets/<name> before the app starts."
echo ""
echo "    Next step: kubectl apply -f ../test-workload/"
