#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
ok()   { echo -e "${GREEN}[OK]${NC}    $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }
die()  { echo -e "${RED}[ERR]${NC}   $*" >&2; exit 1; }
step() { echo -e "\n${BLUE}══════════════════════════════════════${NC}"; log "$*"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
CLUSTER="vector-multi-tier"
NS="logging"

step "Pre-flight checks"
for t in kind kubectl helm; do
  command -v "$t" &>/dev/null && ok "$t found" || die "$t not installed"
done

step "Creating kind cluster '${CLUSTER}'"
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER}$"; then
  warn "Cluster '${CLUSTER}' already exists — skipping."
else
  kind create cluster --config "${ROOT_DIR}/kind-cluster.yml"
  ok "Cluster created."
fi
kubectl cluster-info --context "kind-${CLUSTER}"

step "Helm repos"
helm repo add grafana https://grafana.github.io/helm-charts 2>/dev/null || true
helm repo add vector  https://helm.vector.dev              2>/dev/null || true
helm repo update grafana
helm repo update vector
ok "Repos updated."

step "Namespace"
kubectl create namespace "${NS}" --dry-run=client -o yaml | kubectl apply -f -
ok "Namespace '${NS}' ready."

step "Loki"
helm upgrade --install loki grafana/loki \
  -n "${NS}" --values "${ROOT_DIR}/helm/loki-values.yml" --wait --timeout 5m
ok "Loki ready."

step "Vector ConfigMaps"
kubectl apply -f "${ROOT_DIR}/helm/vector-agent-configmap.yml"
kubectl apply -f "${ROOT_DIR}/helm/vector-aggregator-configmap.yml"
ok "ConfigMaps applied."

step "Vector Aggregator (StatefulSet)"
helm upgrade --install vector-aggregator vector/vector \
  -n "${NS}" --values "${ROOT_DIR}/helm/vector-aggregator-values.yml" --wait --timeout 5m
kubectl rollout status statefulset/vector-aggregator -n "${NS}" --timeout=3m || true
ok "Aggregator ready."

step "Vector Agent (DaemonSet)"
helm upgrade --install vector-agent vector/vector \
  -n "${NS}" --values "${ROOT_DIR}/helm/vector-agent-values.yml" --wait --timeout 5m
kubectl rollout status daemonset/vector-agent -n "${NS}" --timeout=3m || true
ok "Agents ready."

step "Grafana"
helm upgrade --install grafana grafana/grafana \
  -n "${NS}" --values "${ROOT_DIR}/helm/grafana-values.yml" --wait --timeout 5m
ok "Grafana ready."

step "Status"
kubectl get pods -n "${NS}" -o wide
echo ""
kubectl get svc  -n "${NS}"

echo -e "
${GREEN}══════════════════════════════════════${NC}
${GREEN}  Setup complete!${NC}
${GREEN}══════════════════════════════════════${NC}

  Grafana   → ${BLUE}http://localhost:3001${NC}  (admin / admin)
  Loki API  → ${BLUE}http://localhost:3101${NC}

  Watch Aggregator:
    ${YELLOW}kubectl logs -n ${NS} -l app.kubernetes.io/name=vector-aggregator -f${NC}

  Watch Agents:
    ${YELLOW}kubectl logs -n ${NS} -l app.kubernetes.io/name=vector-agent -f${NC}
"
