#!/usr/bin/env bash
# =============================================================
# teardown.sh — delete the kind cluster and all resources
# =============================================================
set -euo pipefail

BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
ok()   { echo -e "${GREEN}[OK]${NC}    $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }

CLUSTER_NAME="vector-demo"

warn "This will delete the kind cluster '${CLUSTER_NAME}' and all data."
read -r -p "Continue? [y/N] " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { log "Aborted."; exit 0; }

if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
  log "Deleting cluster '${CLUSTER_NAME}'..."
  kind delete cluster --name "${CLUSTER_NAME}"
  ok "Cluster deleted."
else
  warn "Cluster '${CLUSTER_NAME}' not found — nothing to delete."
fi
