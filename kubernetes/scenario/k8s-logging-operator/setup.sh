#!/usr/bin/env bash
set -euo pipefail

# ===== Registry config =====
HUB="hub.mecan.ir"        # Docker Hub mirror
K8S="k8s.mecan.ir"        # registry.k8s.io mirror  (unused here but kept for reference)
GHCR="github.mecan.ir"    # ghcr.io mirror

CLUSTER_NAME="logging-demo"
OPERATOR_CHART="4.2.3"
OPERATOR_IMAGE_TAG="4.2.2"
# ===========================

log() { echo -e "\n\033[1;34m>>> $*\033[0m"; }
ok()  { echo -e "\033[1;32m    OK: $*\033[0m"; }

# ---------- 0. pre-flight ----------
for cmd in kind kubectl helm; do
  command -v "$cmd" &>/dev/null || { echo "ERROR: $cmd not found"; exit 1; }
done

# ---------- 1. kind cluster ----------
log "Creating kind cluster: $CLUSTER_NAME"
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
  echo "    Cluster already exists, skipping."
else
  mkdir -p /tmp/kind-logs
  kind create cluster --config kind-cluster.yaml
fi
kubectl cluster-info --context "kind-${CLUSTER_NAME}"
ok "Cluster ready"

# ---------- 2. namespace ----------
log "Creating logging namespace"
kubectl create namespace logging --dry-run=client -o yaml | kubectl apply -f -
ok "Namespace ready"

# ---------- 3. logging operator via helm ----------
log "Installing kube-logging/logging-operator chart=${OPERATOR_CHART} image=${OPERATOR_IMAGE_TAG}"
helm repo add kube-logging https://kube-logging.github.io/helm-charts 2>/dev/null || true
helm repo update kube-logging

helm upgrade --install logging-operator kube-logging/logging-operator \
  --namespace logging \
  --version "$OPERATOR_CHART" \
  --set "image.repository=${GHCR}/kube-logging/logging-operator" \
  --set "image.tag=${OPERATOR_IMAGE_TAG}" \
  --wait \
  --timeout 3m

ok "Logging operator installed"

# ---------- 4. ELK stack ----------
log "Deploying Elasticsearch"
kubectl apply -f manifests/elasticsearch.yaml

log "Deploying Kibana"
kubectl apply -f manifests/kibana.yaml

log "Waiting for Elasticsearch to be ready (up to 5 min)..."
kubectl rollout status statefulset/elasticsearch -n logging --timeout=300s
ok "Elasticsearch ready"

log "Waiting for Kibana to be ready (up to 3 min)..."
kubectl rollout status deployment/kibana -n logging --timeout=180s
ok "Kibana ready"

# ---------- 5. logging CRDs ----------
log "Applying Logging / Output / Flow config"
kubectl apply -f manifests/logging-config.yaml
ok "Logging config applied"

# ---------- 6. demo app ----------
log "Deploying log-generator demo app"
kubectl apply -f manifests/demo-app.yaml
ok "Demo app deployed"

# ---------- 7. summary ----------
echo ""
echo "================================================================"
echo " Setup complete!"
echo "================================================================"
echo " Kibana:        http://localhost:5601"
echo " Elasticsearch: http://localhost:9200"
echo ""
echo " Check pods:"
echo "   kubectl get pods -n logging"
echo ""
echo " Tail operator logs:"
echo "   kubectl logs -n logging -l app.kubernetes.io/name=logging-operator -f"
echo "================================================================"
