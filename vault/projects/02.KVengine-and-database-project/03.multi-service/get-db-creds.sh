#!/usr/bin/env bash
# Simulates a service requesting dynamic Postgres credentials from Vault.
#
# Usage:
#   ./get-db-creds.sh <role_id> <secret_id> <db_role>
#
# Example:
#   ./get-db-creds.sh abc-123 xyz-456 user-service-role
set -euo pipefail

VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
ROLE_ID="${1:?provide role_id}"
SECRET_ID="${2:?provide secret_id}"
DB_ROLE="${3:?provide db_role  (e.g. user-service-role)}"

jq_field() { echo "$1" | python3 -c "import sys,json; print(json.load(sys.stdin)$2)"; }

echo "==> Step 1: AppRole login → short-lived Vault token"
LOGIN=$(curl -sf "${VAULT_ADDR}/v1/auth/approle/login" \
  --request POST \
  --data "{\"role_id\":\"${ROLE_ID}\",\"secret_id\":\"${SECRET_ID}\"}")
TOKEN=$(jq_field "${LOGIN}" "['auth']['client_token']")
TTL=$(jq_field   "${LOGIN}" "['auth']['lease_duration']")
echo "    Token acquired (TTL: ${TTL}s)"

echo ""
echo "==> Step 2: Request dynamic Postgres credentials for role '${DB_ROLE}'"
CREDS=$(curl -sf "${VAULT_ADDR}/v1/database/creds/${DB_ROLE}" \
  --request GET \
  --header "X-Vault-Token: ${TOKEN}")

DB_USER=$(jq_field "${CREDS}" "['data']['username']")
DB_PASS=$(jq_field "${CREDS}" "['data']['password']")
LEASE_ID=$(jq_field "${CREDS}" "['lease_id']")
LEASE_TTL=$(jq_field "${CREDS}" "['lease_duration']")

echo ""
echo "    username  = ${DB_USER}"
echo "    password  = ${DB_PASS}"
echo "    lease_id  = ${LEASE_ID}"
echo "    lease_ttl = ${LEASE_TTL}s"
echo ""
echo "==> This user now exists in Postgres. Vault will DROP it when the lease expires."
echo "    To renew:  PUT /v1/sys/leases/renew   {\"lease_id\": \"${LEASE_ID}\"}"
echo "    To revoke: PUT /v1/sys/leases/revoke  {\"lease_id\": \"${LEASE_ID}\"}"
