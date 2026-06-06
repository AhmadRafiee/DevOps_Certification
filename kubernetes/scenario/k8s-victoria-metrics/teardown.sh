#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="vm-monitoring"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { echo -e "\033[0;34m[INFO]\033[0m  $*"; }
success() { echo -e "${GREEN}[OK]\033[0m    $*"; }
warn()    { echo -e "${YELLOW}[WARN]\033[0m  $*"; }

echo -e "${RED}"
echo "  ⚠  This will permanently delete:"
echo "     • kind cluster '${CLUSTER_NAME}' and all its data"
echo "     • Helm release and all monitoring resources"
echo "     • Temporary worker data dirs (/tmp/vm-worker1, /tmp/vm-worker2)"
echo -e "${NC}"
read -r -p "Are you sure? (yes/N): " CONFIRM
[[ "$CONFIRM" == "yes" ]] || { warn "Aborted."; exit 0; }

# ─── 1. Delete kind cluster ──────────────────────────────────
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
  info "Deleting kind cluster '${CLUSTER_NAME}'..."
  kind delete cluster --name "${CLUSTER_NAME}"
  success "Cluster deleted."
else
  warn "Cluster '${CLUSTER_NAME}' not found — skipping."
fi

# ─── 2. Remove worker data dirs ──────────────────────────────
info "Removing worker data directories..."
rm -rf /tmp/vm-worker1 /tmp/vm-worker2
success "Temp directories removed."

# ─── 3. Remove leftover kubectl context ─────────────────────
if kubectl config get-contexts "kind-${CLUSTER_NAME}" &>/dev/null; then
  kubectl config delete-context "kind-${CLUSTER_NAME}" 2>/dev/null || true
  kubectl config delete-cluster "kind-${CLUSTER_NAME}" 2>/dev/null || true
  kubectl config unset "users.kind-${CLUSTER_NAME}" 2>/dev/null || true
  success "kubectl context cleaned up."
fi

echo ""
echo -e "${GREEN}Teardown complete.${NC}"
