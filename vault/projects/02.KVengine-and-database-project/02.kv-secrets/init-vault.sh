#!/usr/bin/env bash
# Initializes Vault with secrets, policies, and AppRole auth for services.
# Uses only curl — no vault CLI required.
# Run this after `docker compose up -d` in 01.setup/.
set -euo pipefail

VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
VAULT_TOKEN="${VAULT_TOKEN:-myroot}"

# Wrapper: POST/PUT JSON to Vault, exit on non-2xx
vault_post() {
  local path="$1"
  local payload="$2"
  local method="${3:-POST}"
  curl -sf \
    --request "${method}" \
    --header "X-Vault-Token: ${VAULT_TOKEN}" \
    --header "Content-Type: application/json" \
    --data "${payload}" \
    "${VAULT_ADDR}/v1/${path}"
}

# Wrapper: GET from Vault, exit on non-2xx
vault_get() {
  local path="$1"
  curl -sf \
    --request GET \
    --header "X-Vault-Token: ${VAULT_TOKEN}" \
    "${VAULT_ADDR}/v1/${path}"
}

# Extract a top-level field from a JSON response
json_field() {
  local json="$1"
  local field="$2"
  echo "${json}" | python3 -c "import sys,json; print(json.load(sys.stdin)${field})"
}

# ─────────────────────────────────────────────────────────────────────────────

check_vault() {
  echo "==> Checking Vault is reachable..."
  until curl -sf "${VAULT_ADDR}/v1/sys/health" > /dev/null; do
    echo "    Waiting for Vault..."
    sleep 2
  done
  echo "    Vault is up."
}

# ─────────────────────────────────────────────────────────────────────────────

enable_kv() {
  echo ""
  echo "==> Enabling KV v2 secrets engine at 'secret/'..."

  # In dev mode, KV v1 is already mounted at secret/ — upgrade its options to v2
  # PUT /v1/sys/mounts/secret/tune
  vault_post "sys/mounts/secret/tune" \
    '{"options": {"version": "2"}}' \
    PUT > /dev/null && echo "    KV upgraded to v2  ✓" && return

  # If the mount didn't exist at all, enable it from scratch
  # POST /v1/sys/mounts/secret
  vault_post "sys/mounts/secret" \
    '{"type": "kv", "options": {"version": "2"}}' \
    POST > /dev/null && echo "    KV v2 enabled  ✓"
}

# ─────────────────────────────────────────────────────────────────────────────

write_secrets() {
  echo ""
  echo "==> Writing secrets..."

  # KV v2 write endpoint: POST /v1/secret/data/<path>
  # Payload must be wrapped in {"data": {...}}

  # PostgreSQL credentials (used by app-service)
  vault_post "secret/data/database/postgres" \
    '{"data": {"username": "app_user", "password": "S3cur3_DB_P@ss!"}}' > /dev/null
  echo "    secret/database/postgres    ✓"

  # Redis password (used by app-service)
  vault_post "secret/data/services/redis" \
    '{"data": {"password": "R3d!sP@ss#2026"}}' > /dev/null
  echo "    secret/services/redis       ✓"

  # API Gateway key (used by api-gateway only)
  vault_post "secret/data/services/api-gateway" \
    '{"data": {"api_key": "gw-ak-7f3c9b2e4d1a"}}' > /dev/null
  echo "    secret/services/api-gateway ✓"
}

# ─────────────────────────────────────────────────────────────────────────────

write_policies() {
  echo ""
  echo "==> Writing policies..."

  # Policies are sent as a JSON string with the HCL inside the "policy" field.
  # PUT /v1/sys/policies/acl/<name>

  # app-service-policy: read DB + Redis
  vault_post "sys/policies/acl/app-service-policy" \
    '{"policy": "path \"secret/data/database/postgres\" {\n  capabilities = [\"read\"]\n}\npath \"secret/data/services/redis\" {\n  capabilities = [\"read\"]\n}"}' \
    PUT > /dev/null
  echo "    app-service-policy  ✓"

  # api-gateway-policy: read only its own secret
  vault_post "sys/policies/acl/api-gateway-policy" \
    '{"policy": "path \"secret/data/services/api-gateway\" {\n  capabilities = [\"read\"]\n}"}' \
    PUT > /dev/null
  echo "    api-gateway-policy  ✓"
}

# ─────────────────────────────────────────────────────────────────────────────

enable_approle() {
  echo ""
  echo "==> Enabling AppRole auth method..."

  # POST /v1/sys/auth/approle
  vault_post "sys/auth/approle" \
    '{"type": "approle"}' > /dev/null 2>&1 || echo "    AppRole already enabled."

  # Create role for app-service
  # POST /v1/auth/approle/role/<name>
  vault_post "auth/approle/role/app-service" \
    '{"token_policies": ["app-service-policy"], "token_ttl": "1h", "token_max_ttl": "24h"}' \
    POST > /dev/null
  echo "    role/app-service    ✓"

  # Create role for api-gateway
  vault_post "auth/approle/role/api-gateway" \
    '{"token_policies": ["api-gateway-policy"], "token_ttl": "1h", "token_max_ttl": "24h"}' \
    POST > /dev/null
  echo "    role/api-gateway    ✓"
}

# ─────────────────────────────────────────────────────────────────────────────

print_credentials() {
  echo ""
  echo "==> AppRole credentials for services"
  echo "    (hand RoleID to the service via config; generate a fresh SecretID per deploy)"
  echo ""

  # GET /v1/auth/approle/role/<name>/role-id
  APP_ROLE_RESP=$(vault_get "auth/approle/role/app-service/role-id")
  APP_ROLE_ID=$(json_field "${APP_ROLE_RESP}" "['data']['role_id']")

  # POST /v1/auth/approle/role/<name>/secret-id  (empty body = generate new one)
  APP_SECRET_RESP=$(vault_post "auth/approle/role/app-service/secret-id" '{}')
  APP_SECRET_ID=$(json_field "${APP_SECRET_RESP}" "['data']['secret_id']")

  GW_ROLE_RESP=$(vault_get "auth/approle/role/api-gateway/role-id")
  GW_ROLE_ID=$(json_field "${GW_ROLE_RESP}" "['data']['role_id']")

  GW_SECRET_RESP=$(vault_post "auth/approle/role/api-gateway/secret-id" '{}')
  GW_SECRET_ID=$(json_field "${GW_SECRET_RESP}" "['data']['secret_id']")

  echo "  [app-service]"
  echo "    VAULT_ROLE_ID   = ${APP_ROLE_ID}"
  echo "    VAULT_SECRET_ID = ${APP_SECRET_ID}"
  echo ""
  echo "  [api-gateway]"
  echo "    VAULT_ROLE_ID   = ${GW_ROLE_ID}"
  echo "    VAULT_SECRET_ID = ${GW_SECRET_ID}"
  echo ""
  echo "  Save these in your .env (never commit them)."
  echo "  Then run: ./get-secret.sh \$VAULT_ROLE_ID \$VAULT_SECRET_ID secret/database/postgres"
}

# ─────────────────────────────────────────────────────────────────────────────

check_vault
enable_kv
write_secrets
write_policies
enable_approle
print_credentials
