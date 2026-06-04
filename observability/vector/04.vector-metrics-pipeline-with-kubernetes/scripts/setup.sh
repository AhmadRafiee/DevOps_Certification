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
CLUSTER="vector-metrics"
NS="monitoring"
LOG_NS="logging"   # Loki + Grafana live here

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
helm repo add grafana             https://grafana.github.io/helm-charts         2>/dev/null || true
helm repo add vector              https://helm.vector.dev                        2>/dev/null || true
helm repo add vm                  https://victoriametrics.github.io/helm-charts/ 2>/dev/null || true
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo update grafana
helm repo update vector
helm repo update vm
helm repo update prometheus-community
ok "Repos updated."

step "Namespaces"
kubectl create namespace "${NS}"     --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace "${LOG_NS}" --dry-run=client -o yaml | kubectl apply -f -
ok "Namespaces ready."

step "VictoriaMetrics (single binary)"
helm upgrade --install victoria-metrics vm/victoria-metrics-single \
  -n "${NS}" --values "${ROOT_DIR}/helm/victoriametrics-values.yml" --wait --timeout 5m
ok "VictoriaMetrics ready."

step "kube-state-metrics"
helm upgrade --install kube-state-metrics prometheus-community/kube-state-metrics \
  -n "${NS}" --values "${ROOT_DIR}/helm/kube-state-metrics-values.yml" --wait --timeout 3m
ok "kube-state-metrics ready."

step "Loki (for raw log storage)"
helm upgrade --install loki grafana/loki \
  -n "${LOG_NS}" --values "${ROOT_DIR}/helm/loki-values.yml" \
  --wait --timeout 5m
ok "Loki ready."

step "nginx demo workload"
kubectl apply -f "${ROOT_DIR}/helm/nginx-demo.yml"
ok "nginx-demo deployed."

step "Vector ConfigMap + DaemonSet"
kubectl apply -f "${ROOT_DIR}/helm/vector-configmap.yml"
helm upgrade --install vector vector/vector \
  -n "${NS}" --values "${ROOT_DIR}/helm/vector-values.yml" --wait --timeout 5m
kubectl rollout status daemonset/vector -n "${NS}" --timeout=3m || true
ok "Vector ready."

step "Grafana"
helm upgrade --install grafana grafana/grafana \
  -n "${NS}" --values "${ROOT_DIR}/helm/grafana-values.yml" --wait --timeout 5m
ok "Grafana ready."

step "Status"
kubectl get pods -n "${NS}" -o wide
echo ""
kubectl get pods -n "${LOG_NS}" -o wide
echo ""

echo -e "
${GREEN}══════════════════════════════════════${NC}
${GREEN}  Setup complete!${NC}
${GREEN}══════════════════════════════════════${NC}

  Grafana          → ${BLUE}http://localhost:3002${NC}  (admin / admin)
  VictoriaMetrics  → ${BLUE}http://localhost:8428${NC}
  Loki API         → ${BLUE}http://localhost:3103${NC}

  Check metrics in VictoriaMetrics:
    ${YELLOW}curl 'http://localhost:8428/api/v1/label/__name__/values' | jq${NC}

  Watch nginx log-to-metric:
    ${YELLOW}curl 'http://localhost:8428/api/v1/query?query=app_http_requests_total' | jq${NC}

  Watch Vector:
    ${YELLOW}kubectl logs -n ${NS} -l app.kubernetes.io/name=vector -f --tail=20${NC}
"
