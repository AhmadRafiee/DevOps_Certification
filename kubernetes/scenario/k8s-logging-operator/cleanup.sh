#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="logging-demo"

log() { echo -e "\n\033[1;34m>>> $*\033[0m"; }
ok()  { echo -e "\033[1;32m    OK: $*\033[0m"; }

log "Deleting kind cluster: $CLUSTER_NAME"
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
  kind delete cluster --name "$CLUSTER_NAME"
  ok "Cluster deleted"
else
  echo "    Cluster not found, skipping."
fi

log "Removing Helm repo"
helm repo remove kube-logging 2>/dev/null && ok "Repo removed" || echo "    Repo not found, skipping."

echo ""
echo "================================================================"
echo " Cleanup complete!"
echo "================================================================"
