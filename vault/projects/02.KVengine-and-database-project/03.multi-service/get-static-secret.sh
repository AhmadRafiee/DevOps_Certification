#!/usr/bin/env bash
# Simulates a service reading a static KV secret from Vault.
#
# Usage:
#   ./get-static-secret.sh <role_id> <secret_id> <secret_path>
#
# Example:
#   ./get-static-secret.sh abc-123 xyz-456 secret/services/payment/stripe
set -euo pipefail

VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
ROLE_ID="${1:?provide role_id}"
SECRET_ID="${2:?provide secret_id}"
SECRET_PATH="${3:?provide secret_path  (e.g. secret/services/payment/stripe)}"

jq_field() { echo "$1" | python3 -c "import sys,json; print(json.load(sys.stdin)$2)"; }

# KV v2 stores data under /data/ — rewrite secret/foo → secret/data/foo
KV_PATH="${SECRET_PATH/secret\//secret\/data\/}"

echo "==> Step 1: AppRole login → short-lived Vault token"
LOGIN=$(curl -sf "${VAULT_ADDR}/v1/auth/approle/login" \
  --request POST \
  --data "{\"role_id\":\"${ROLE_ID}\",\"secret_id\":\"${SECRET_ID}\"}")
TOKEN=$(jq_field "${LOGIN}" "['auth']['client_token']")
TTL=$(jq_field   "${LOGIN}" "['auth']['lease_duration']")
echo "    Token acquired (TTL: ${TTL}s)"

echo ""
echo "==> Step 2: Read static secret at '${SECRET_PATH}'"
RESP=$(curl -sf "${VAULT_ADDR}/v1/${KV_PATH}" \
  --request GET \
  --header "X-Vault-Token: ${TOKEN}")

echo ""
echo "    Fields:"
echo "${RESP}" | python3 -c "
import sys, json
data = json.load(sys.stdin)['data']['data']
for k, v in data.items():
    print(f'    {k} = {v}')
"
