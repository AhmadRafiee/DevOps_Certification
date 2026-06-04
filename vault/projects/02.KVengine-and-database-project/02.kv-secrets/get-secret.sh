#!/usr/bin/env bash
# Simulates how a service retrieves a secret from Vault using AppRole.
#
# Usage:
#   ./get-secret.sh <role_id> <secret_id> <secret_path>
#
# Example:
#   ./get-secret.sh abc-123 xyz-456 secret/database/postgres
set -euo pipefail

VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
ROLE_ID="${1:?Usage: $0 <role_id> <secret_id> <secret_path>}"
SECRET_ID="${2:?Usage: $0 <role_id> <secret_id> <secret_path>}"
SECRET_PATH="${3:?Usage: $0 <role_id> <secret_id> <secret_path>}"

echo "==> Step 1: Authenticate with AppRole → get a short-lived token"

LOGIN_RESPONSE=$(curl -sf "${VAULT_ADDR}/v1/auth/approle/login" \
  --request POST \
  --data "{\"role_id\":\"${ROLE_ID}\",\"secret_id\":\"${SECRET_ID}\"}")

CLIENT_TOKEN=$(echo "${LOGIN_RESPONSE}" | python3 -c "import sys,json; print(json.load(sys.stdin)['auth']['client_token'])")
TOKEN_TTL=$(echo   "${LOGIN_RESPONSE}" | python3 -c "import sys,json; print(json.load(sys.stdin)['auth']['lease_duration'])")

echo "    Token obtained (TTL: ${TOKEN_TTL}s)"

echo ""
echo "==> Step 2: Read secret at '${SECRET_PATH}'"

# KV v2 stores data under /data/ in the path
KV_API_PATH="${VAULT_ADDR}/v1/${SECRET_PATH/secret\//secret/data/}"

SECRET_RESPONSE=$(curl -sf "${KV_API_PATH}" \
  --header "X-Vault-Token: ${CLIENT_TOKEN}")

echo ""
echo "    Raw response:"
echo "${SECRET_RESPONSE}" | python3 -m json.tool

echo ""
echo "==> Step 3: Extract individual fields"
echo "${SECRET_RESPONSE}" | python3 -c "
import sys, json
data = json.load(sys.stdin)['data']['data']
for key, value in data.items():
    print(f'    {key} = {value}')
"

echo ""
echo "==> Done. The service now holds the secret in memory — never written to disk."
