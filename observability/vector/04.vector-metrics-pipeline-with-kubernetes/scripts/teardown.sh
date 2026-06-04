#!/usr/bin/env bash
set -euo pipefail
YELLOW='\033[1;33m'; GREEN='\033[0;32m'; NC='\033[0m'
warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }
ok()   { echo -e "${GREEN}[OK]${NC}    $*"; }

CLUSTER="vector-metrics"
warn "This will delete cluster '${CLUSTER}' and all data."
read -r -p "Continue? [y/N] " c
[[ "$c" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }
kind delete cluster --name "${CLUSTER}" && ok "Done."
