#!/usr/bin/env bash
# Full multi-service Vault setup — no vault CLI, pure curl.
#
# To add a service:
#   1. Add its name to SERVICES
#   2. Add its policy to POLICIES[name]
#   3. If it needs a DB user, add DB_ROLES[name] and DB_ROLE_TTL[role-name]
#
# Prerequisites:
#   cd 01.setup         && docker compose up -d   (Vault)
#   cd 03.multi-service && docker compose up -d   (Postgres)
set -euo pipefail

# ── Infrastructure ────────────────────────────────────────────────────────────

VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
VAULT_TOKEN="${VAULT_TOKEN:-myroot}"
PG_HOST="${PG_HOST:-postgres_vault_lab}"
PG_PORT="${PG_PORT:-5432}"
PG_DB="${PG_DB:-appdb}"
PG_ADMIN_USER="${PG_ADMIN_USER:-vault_admin}"
PG_ADMIN_PASS="${PG_ADMIN_PASS:-VaultAdmin!Pass}"

# ── Service definitions ───────────────────────────────────────────────────────

SERVICES=(
  api-gateway
  user-service
  order-service
  payment-service
  notification-service
  search-service
)

# Policy HCL for each service — only the paths it's allowed to read
declare -A POLICIES

POLICIES[api-gateway]='
path "secret/data/shared/jwt"                  { capabilities = ["read"] }
path "secret/data/services/api-gateway/admin"  { capabilities = ["read"] }
'

POLICIES[user-service]='
path "database/creds/user-service-role"  { capabilities = ["read"] }
path "secret/data/shared/redis"          { capabilities = ["read"] }
'

POLICIES[order-service]='
path "database/creds/order-service-role"  { capabilities = ["read"] }
path "secret/data/shared/redis"           { capabilities = ["read"] }
path "secret/data/shared/rabbitmq"        { capabilities = ["read"] }
'

POLICIES[payment-service]='
path "database/creds/payment-service-role"     { capabilities = ["read"] }
path "secret/data/services/payment/stripe"     { capabilities = ["read"] }
'

POLICIES[notification-service]='
path "secret/data/services/notification/sendgrid"  { capabilities = ["read"] }
path "secret/data/services/notification/smtp"      { capabilities = ["read"] }
path "secret/data/shared/rabbitmq"                 { capabilities = ["read"] }
'

POLICIES[search-service]='
path "secret/data/services/search/elasticsearch"  { capabilities = ["read"] }
'

# DB role per service — empty string means no dynamic DB credentials
declare -A DB_ROLES
DB_ROLES[api-gateway]=""
DB_ROLES[user-service]="user-service-role"
DB_ROLES[order-service]="order-service-role"
DB_ROLES[payment-service]="payment-service-role"
DB_ROLES[notification-service]=""
DB_ROLES[search-service]=""

# TTL for each DB role: "default_ttl|max_ttl"
declare -A DB_ROLE_TTL
DB_ROLE_TTL[user-service-role]="1h|24h"
DB_ROLE_TTL[order-service-role]="1h|24h"
DB_ROLE_TTL[payment-service-role]="30m|4h"

# ── HTTP helpers ──────────────────────────────────────────────────────────────

v_post() {   # v_post <path> <json> [METHOD]
  local method="${3:-POST}"
  curl -sf \
    --request "${method}" \
    --header "X-Vault-Token: ${VAULT_TOKEN}" \
    --header "Content-Type: application/json" \
    --data "$2" \
    "${VAULT_ADDR}/v1/$1"
}

v_get() {    # v_get <path>
  curl -sf \
    --request GET \
    --header "X-Vault-Token: ${VAULT_TOKEN}" \
    "${VAULT_ADDR}/v1/$1"
}

jq_field() { echo "$1" | python3 -c "import sys,json; print(json.load(sys.stdin)$2)"; }

ok() { echo "    $1  ✓"; }

# ── Health checks ─────────────────────────────────────────────────────────────

wait_vault() {
  echo "==> Waiting for Vault..."
  until curl -sf "${VAULT_ADDR}/v1/sys/health" >/dev/null; do sleep 2; done
  ok "Vault is up"
}

wait_postgres() {
  echo ""
  echo "==> Waiting for Postgres..."
  until docker exec "${PG_HOST}" pg_isready -U "${PG_ADMIN_USER}" -d "${PG_DB}" -q 2>/dev/null; do
    echo "    Waiting for Postgres..."
    sleep 2
  done
  ok "Postgres is up"
}

# ── KV v2 + static secrets ────────────────────────────────────────────────────

setup_kv() {
  echo ""
  echo "==> KV v2 secrets engine..."

  v_post "sys/mounts/secret/tune" '{"options":{"version":"2"}}' PUT >/dev/null 2>&1 \
    || v_post "sys/mounts/secret" '{"type":"kv","options":{"version":"2"}}' >/dev/null 2>&1 \
    || true
  ok "secret/ (KV v2)"

  echo ""
  echo "    Writing static secrets..."

  v_post "secret/data/shared/redis" \
    '{"data":{"password":"R3d!sShared#26"}}' >/dev/null
  ok "secret/shared/redis"

  v_post "secret/data/shared/rabbitmq" \
    '{"data":{"username":"rmq_app","password":"RMQ_P@ss!26"}}' >/dev/null
  ok "secret/shared/rabbitmq"

  v_post "secret/data/shared/jwt" \
    '{"data":{"secret":"jwt-hs256-super-secret-key","algorithm":"HS256"}}' >/dev/null
  ok "secret/shared/jwt"

  v_post "secret/data/services/api-gateway/admin" \
    '{"data":{"token":"adm-tk-9f2c1b4e","dashboard_pass":"Adm!nD@sh#26"}}' >/dev/null
  ok "secret/services/api-gateway/admin"

  v_post "secret/data/services/payment/stripe" \
    '{"data":{"api_key":"sk_test_4eC39HqLyjWDarjtT1zdp7dc","webhook_secret":"whsec_abc123"}}' >/dev/null
  ok "secret/services/payment/stripe"

  v_post "secret/data/services/notification/sendgrid" \
    '{"data":{"api_key":"SG.xxxx.yyyy","from_email":"no-reply@example.com"}}' >/dev/null
  ok "secret/services/notification/sendgrid"

  v_post "secret/data/services/notification/smtp" \
    '{"data":{"host":"smtp.example.com","port":"587","username":"smtp_user","password":"SMTP_P@ss!"}}' >/dev/null
  ok "secret/services/notification/smtp"

  v_post "secret/data/services/search/elasticsearch" \
    '{"data":{"url":"http://elasticsearch:9200","api_key":"es-ak-8d3f7a","index_prefix":"app_"}}' >/dev/null
  ok "secret/services/search/elasticsearch"
}

# ── Database secrets engine ───────────────────────────────────────────────────

setup_database_engine() {
  echo ""
  echo "==> Database secrets engine (dynamic Postgres users)..."

  v_post "sys/mounts/database" '{"type":"database"}' >/dev/null 2>&1 || true
  ok "database/ engine enabled"

  # Build allowed_roles list from DB_ROLES
  local allowed_roles=""
  for svc in "${SERVICES[@]}"; do
    local role="${DB_ROLES[$svc]:-}"
    [[ -n "$role" ]] && allowed_roles+="${role},"
  done
  allowed_roles="${allowed_roles%,}"   # strip trailing comma

  v_post "database/config/postgres" "$(python3 -c "
import json
print(json.dumps({
  'plugin_name': 'postgresql-database-plugin',
  'connection_url': 'postgresql://{{username}}:{{password}}@${PG_HOST}:${PG_PORT}/${PG_DB}?sslmode=disable',
  'allowed_roles': '${allowed_roles}',
  'username': '${PG_ADMIN_USER}',
  'password': '${PG_ADMIN_PASS}',
}))
")" >/dev/null
  ok "database/config/postgres  (allowed_roles: ${allowed_roles})"

  # Create one DB role per service that has a DB_ROLES entry
  local creation_sql
  creation_sql=$(python3 -c "
import json
print(json.dumps([
  \"CREATE ROLE \\\"{{name}}\\\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'\",
  \"GRANT SELECT,INSERT,UPDATE,DELETE ON ALL TABLES IN SCHEMA public TO \\\"{{name}}\\\"\"
]))
")
  for svc in "${SERVICES[@]}"; do
    local role="${DB_ROLES[$svc]:-}"
    [[ -z "$role" ]] && continue

    local ttl="${DB_ROLE_TTL[$role]}"
    local default_ttl="${ttl%%|*}"
    local max_ttl="${ttl##*|}"

    v_post "database/roles/${role}" "$(python3 -c "
import json
print(json.dumps({
  'db_name': 'postgres',
  'creation_statements': ${creation_sql},
  'default_ttl': '${default_ttl}',
  'max_ttl': '${max_ttl}',
}))
")" >/dev/null
    ok "database/roles/${role}  (TTL ${default_ttl} / max ${max_ttl})"
  done
}

# ── Policies ──────────────────────────────────────────────────────────────────

write_policies() {
  echo ""
  echo "==> Writing policies..."

  for svc in "${SERVICES[@]}"; do
    local payload
    payload=$(python3 -c "
import json, sys
print(json.dumps({'policy': sys.stdin.read()}))
" <<< "${POLICIES[$svc]}")

    v_post "sys/policies/acl/${svc}-policy" "${payload}" PUT >/dev/null
    ok "${svc}-policy"
  done
}

# ── AppRole ───────────────────────────────────────────────────────────────────

setup_approle() {
  echo ""
  echo "==> AppRole auth method..."

  v_post "sys/auth/approle" '{"type":"approle"}' >/dev/null 2>&1 || true
  ok "approle auth enabled"

  for svc in "${SERVICES[@]}"; do
    v_post "auth/approle/role/${svc}" \
      "{\"token_policies\":[\"${svc}-policy\"],\"token_ttl\":\"1h\",\"token_max_ttl\":\"24h\"}" \
      POST >/dev/null
    ok "role/${svc}"
  done
}

# ── Print credentials ─────────────────────────────────────────────────────────

print_credentials() {
  echo ""
  echo "==> AppRole credentials"
  echo "    ┌─────────────────────────────────────────────────────────────────┐"

  for svc in "${SERVICES[@]}"; do
    local role_id secret_id
    role_id=$(jq_field "$(v_get "auth/approle/role/${svc}/role-id")"         "['data']['role_id']")
    secret_id=$(jq_field "$(v_post "auth/approle/role/${svc}/secret-id" '{}')" "['data']['secret_id']")

    printf "    │  [%-22s]\n" "${svc}"
    printf "    │    VAULT_ROLE_ID   = %s\n" "${role_id}"
    printf "    │    VAULT_SECRET_ID = %s\n" "${secret_id}"
    echo  "    │"
  done

  echo "    └─────────────────────────────────────────────────────────────────┘"
  echo ""
  echo "  Test dynamic DB creds:"
  echo "    ./get-db-creds.sh \$ROLE_ID \$SECRET_ID user-service-role"
  echo ""
  echo "  Test static secret:"
  echo "    ./get-static-secret.sh \$ROLE_ID \$SECRET_ID secret/services/payment/stripe"
}

# ── Run ───────────────────────────────────────────────────────────────────────

wait_vault
wait_postgres
setup_kv
setup_database_engine
write_policies
setup_approle
print_credentials
