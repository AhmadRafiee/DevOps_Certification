#!/usr/bin/env bash
# =============================================================
# setup.sh — spin up a kind cluster + Vector + Loki + Grafana
# =============================================================
set -euo pipefail

# ── Colours ───────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'
YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
ok()   { echo -e "${GREEN}[OK]${NC}    $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }
die()  { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }
step() { echo -e "\n${BLUE}════════════════════════════════════════${NC}"; log "$*"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
CLUSTER_NAME="vector-demo"
NAMESPACE="logging"

# ── 0. Pre-flight checks ──────────────────────────────────────
step "Checking required tools"
for tool in kind kubectl helm; do
  if command -v "$tool" &>/dev/null; then
    ok "$tool found: $(${tool} version --short 2>/dev/null | head -1 || ${tool} version 2>/dev/null | head -1)"
  else
    die "$tool is not installed.
  Install guides:
    kind:    https://kind.sigs.k8s.io/docs/user/quick-start/#installation
    kubectl: https://kubernetes.io/docs/tasks/tools/
    helm:    https://helm.sh/docs/intro/install/"
  fi
done

# ── 1. kind cluster ───────────────────────────────────────────
step "Creating kind cluster '${CLUSTER_NAME}'"
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
  warn "Cluster '${CLUSTER_NAME}' already exists — skipping creation."
else
  kind create cluster --config "${ROOT_DIR}/kind-cluster.yml"
  ok "Cluster created."
fi

kubectl cluster-info --context "kind-${CLUSTER_NAME}"

# ── 2. Helm repos ─────────────────────────────────────────────
step "Adding / updating Helm repositories"
helm repo add grafana https://grafana.github.io/helm-charts 2>/dev/null || true
helm repo add vector  https://helm.vector.dev              2>/dev/null || true
helm repo update vector
helm repo update grafana
ok "Repos up to date."

# ── 3. Namespace ──────────────────────────────────────────────
step "Creating namespace '${NAMESPACE}'"
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
ok "Namespace ready."

# ── 4. Loki ───────────────────────────────────────────────────
step "Installing Loki"
helm upgrade --install loki grafana/loki \
  --namespace "${NAMESPACE}" \
  --values    "${ROOT_DIR}/helm/loki-values.yml" \
  --timeout   5m \
  --wait

ok "Loki installed."
log "Waiting for Loki pod to be ready..."
kubectl rollout status statefulset/loki -n "${NAMESPACE}" --timeout=3m || true

# ── 5. Vector ConfigMap (applied before Helm to avoid tpl issue) ──
step "Applying Vector ConfigMap"
kubectl apply -f "${ROOT_DIR}/helm/vector-configmap.yml"
ok "ConfigMap applied."

# ── 6. Vector ─────────────────────────────────────────────────
step "Installing Vector (DaemonSet agent)"
helm upgrade --install vector vector/vector \
  --namespace "${NAMESPACE}" \
  --values    "${ROOT_DIR}/helm/vector-agent-values.yml" \
  --timeout   5m \
  --wait

ok "Vector installed."
kubectl rollout status daemonset/vector -n "${NAMESPACE}" --timeout=3m || true

# ── 6. Grafana ────────────────────────────────────────────────
step "Installing Grafana"
helm upgrade --install grafana grafana/grafana \
  --namespace "${NAMESPACE}" \
  --values    "${ROOT_DIR}/helm/grafana-values.yml" \
  --timeout   5m \
  --wait

ok "Grafana installed."
kubectl rollout status deployment/grafana -n "${NAMESPACE}" --timeout=3m || true

# ── 8. Status ─────────────────────────────────────────────────
step "Final status"
kubectl get pods    -n "${NAMESPACE}"
echo ""
kubectl get svc     -n "${NAMESPACE}"
echo ""

echo -e "
${GREEN}════════════════════════════════════════${NC}
${GREEN}  Setup complete!${NC}
${GREEN}════════════════════════════════════════${NC}

  Grafana   →  ${BLUE}http://localhost:3000${NC}   (admin / admin)
  Loki API  →  ${BLUE}http://localhost:3100${NC}
  Vector API→  ${BLUE}http://localhost:8686${NC}

  View pod logs:
    ${YELLOW}kubectl logs -n ${NAMESPACE} -l app.kubernetes.io/name=vector -f${NC}

  Query Loki directly:
    ${YELLOW}curl -s 'http://localhost:3100/loki/api/v1/labels' | jq${NC}
    ${YELLOW}curl -G http://localhost:3100/loki/api/v1/query_range \\
      --data-urlencode 'query={namespace=\"logging\"}' | jq${NC}
"
