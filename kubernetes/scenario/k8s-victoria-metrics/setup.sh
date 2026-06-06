#!/usr/bin/env bash
set -euo pipefail

# ═══════════════════════════════════════════════════════════
#  VictoriaMetrics Full Monitoring Stack on kind
# ═══════════════════════════════════════════════════════════

CLUSTER_NAME="vm-monitoring"
NAMESPACE="monitoring"
HELM_RELEASE="vm-k8s-stack"
CHART_VERSION="0.81.0"  # pinned — update as needed

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─── 1. Pre-flight checks ───────────────────────────────────
info "Checking required tools..."
for tool in kind kubectl helm docker; do
  command -v "$tool" &>/dev/null || error "$tool not found. Please install it first."
done
docker info &>/dev/null || error "Docker daemon is not running."
success "All tools present."

# ─── 2. Create worker data dirs and registry mirror structure ─
mkdir -p /tmp/vm-worker1 /tmp/vm-worker2
mkdir -p "${SCRIPT_DIR}/registry-mirrors/quay.io"
mkdir -p "${SCRIPT_DIR}/registry-mirrors/registry.k8s.io"
mkdir -p "${SCRIPT_DIR}/registry-mirrors/docker.io"
info "Worker data directories ready."

# ─── 3. Create kind cluster ─────────────────────────────────
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
  warn "Cluster '${CLUSTER_NAME}' already exists — skipping creation."
else
  info "Creating kind cluster '${CLUSTER_NAME}'..."
  kind create cluster \
    --name "${CLUSTER_NAME}" \
    --config "${SCRIPT_DIR}/kind-config.yaml" \
    --wait 120s
  success "Cluster created."
fi

# ─── 4. Set kubectl context ─────────────────────────────────
kubectl config use-context "kind-${CLUSTER_NAME}"
info "kubectl context: kind-${CLUSTER_NAME}"

# ─── 5. Wait for nodes ──────────────────────────────────────
info "Waiting for all nodes to be Ready..."
kubectl wait node --all --for=condition=Ready --timeout=120s
kubectl get nodes -o wide
success "Nodes ready."

# ─── 6. Add Helm repos ──────────────────────────────────────
info "Adding Helm repositories..."
helm repo add vm         https://victoriametrics.github.io/helm-charts/ 2>/dev/null || true
helm repo add grafana    https://grafana.github.io/helm-charts           2>/dev/null || true
helm repo update vm
helm repo update grafana
success "Helm repos updated."

# ─── 7. Create monitoring namespace ─────────────────────────
kubectl get namespace "${NAMESPACE}" &>/dev/null || \
  kubectl create namespace "${NAMESPACE}"
success "Namespace '${NAMESPACE}' ready."

# ─── 8. Install / Upgrade vm-k8s-stack ──────────────────────
# Clean up any stuck failed release before installing
RELEASE_STATUS=$(helm status "${HELM_RELEASE}" -n "${NAMESPACE}" -o json 2>/dev/null | grep -o '"status":"[^"]*"' | head -1 || true)
if echo "${RELEASE_STATUS}" | grep -qE '"status":"(failed|uninstalling|pending-install|pending-upgrade)"'; then
  warn "Found stuck release (${RELEASE_STATUS}) — cleaning up..."
  helm uninstall "${HELM_RELEASE}" -n "${NAMESPACE}" 2>/dev/null || true
fi

info "Installing VictoriaMetrics K8s Stack (chart v${CHART_VERSION})..."
helm upgrade --install "${HELM_RELEASE}" vm/victoria-metrics-k8s-stack \
  --namespace "${NAMESPACE}" \
  --version "${CHART_VERSION}" \
  --values "${SCRIPT_DIR}/values/vm-stack-values.yaml" \
  --set "grafana.adminPassword=admin123" \
  --timeout 10m \
  --wait

success "VictoriaMetrics stack installed."

# ─── 9. Run kind-specific fixes ─────────────────────────────
info "Applying kind-specific component fixes..."
bash "${SCRIPT_DIR}/fix-kind-components.sh"

# ─── 10. Print access info ──────────────────────────────────
echo ""
echo -e "${GREEN}══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  VictoriaMetrics Monitoring Stack is Ready!${NC}"
echo -e "${GREEN}══════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${YELLOW}Grafana${NC}           http://localhost:30000"
echo -e "  ${YELLOW}  user/pass:${NC}      admin / admin123"
echo ""
echo -e "  ${YELLOW}VMSingle (API)${NC}    http://localhost:30001"
echo -e "  ${YELLOW}  query UI:${NC}       http://localhost:30001/vmui"
echo -e "  ${YELLOW}  metrics:${NC}        http://localhost:30001/metrics"
echo ""
echo -e "  ${YELLOW}AlertManager${NC}      http://localhost:30003"
echo ""
echo -e "  Cluster context: ${BLUE}kind-${CLUSTER_NAME}${NC}"
echo ""
echo -e "  Useful commands:"
echo -e "  ${BLUE}kubectl get pods -n ${NAMESPACE}${NC}"
echo -e "  ${BLUE}kubectl get vmservicescrape -n ${NAMESPACE}${NC}"
echo -e "  ${BLUE}kubectl get prometheusrule -n ${NAMESPACE}${NC}"
echo ""
