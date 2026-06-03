#!/usr/bin/env bash
# Configure Vault Database Secrets Engine for dynamic PostgreSQL credentials.
#
# What this script does:
#  1. Enables the database/ secrets engine
#  2. Configures the PostgreSQL connection (using vaultadmin superuser)
#  3. Creates two dynamic roles:
#       app-reader  → ephemeral user with SELECT-only (TTL 1h)
#       app-writer  → ephemeral user with full CRUD   (TTL 15m — short on purpose)
#  4. Creates a Vault policy granting the app access to both roles
#  5. Creates a Kubernetes auth role for the app's ServiceAccount

set -euo pipefail

VAULT_ADDR="${VAULT_ADDR:-http://172.18.0.2:8200}"
VAULT_TOKEN="${VAULT_TOKEN:-myroot}"

# PostgreSQL NodePort address reachable by the Vault container.
# Vault runs in Docker (app_net); PostgreSQL is inside KIND cluster via NodePort 30432.
# Auto-detect the first KIND node IP, or override with PG_NODE_IP env var.
PG_NODE_IP="${PG_NODE_IP:-$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || echo '172.20.0.2')}"
PG_PORT="${PG_PORT:-30432}"
PG_DB="appdb"
PG_ADMIN_USER="vaultadmin"
PG_ADMIN_PASS="vaultadmin-secret"

echo "==> Vault   : $VAULT_ADDR"
echo "==> Postgres: $PG_NODE_IP:$PG_PORT/$PG_DB"
echo ""

# ── helper ────────────────────────────────────────────────────────────────────
vjson() {
    python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))' <<< "$1"
}

vapi() {
    local method="$1"; local path="$2"; shift 2
    curl -sf -X "$method" "$VAULT_ADDR/v1/$path" \
        -H "X-Vault-Token: $VAULT_TOKEN" \
        -H "Content-Type: application/json" \
        "$@" | python3 -m json.tool 2>/dev/null || true
}

# ── 1. Enable database secrets engine ─────────────────────────────────────────
echo "==> Enabling database secrets engine at database/"
curl -sf -X POST "$VAULT_ADDR/v1/sys/mounts/database" \
    -H "X-Vault-Token: $VAULT_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"type":"database"}' >/dev/null 2>&1 \
    && echo "    Enabled" || echo "    (already enabled)"

# ── 2. Configure PostgreSQL plugin ────────────────────────────────────────────
echo ""
echo "==> Configuring PostgreSQL connection: postgres-appdb"
curl -sf -X POST "$VAULT_ADDR/v1/database/config/postgres-appdb" \
    -H "X-Vault-Token: $VAULT_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"plugin_name\":      \"postgresql-database-plugin\",
        \"allowed_roles\":    \"app-reader,app-writer\",
        \"connection_url\":   \"postgresql://{{username}}:{{password}}@${PG_NODE_IP}:${PG_PORT}/${PG_DB}?sslmode=disable\",
        \"username\":         \"${PG_ADMIN_USER}\",
        \"password\":         \"${PG_ADMIN_PASS}\"
    }"
echo ""
echo "    Connection configured"

# ── 3. Role: app-reader (SELECT only, TTL 1h) ─────────────────────────────────
# Vault runs these statements as vaultadmin when issuing read credentials.
echo ""
echo "==> Creating role: app-reader (SELECT-only, TTL=1h)"

READER_CREATE="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT USAGE ON SCHEMA public TO \"{{name}}\"; GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";"
REVOKE_SQL="REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM \"{{name}}\"; REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public FROM \"{{name}}\"; REVOKE USAGE ON SCHEMA public FROM \"{{name}}\"; DROP ROLE IF EXISTS \"{{name}}\";"

curl -sf -X POST "$VAULT_ADDR/v1/database/roles/app-reader" \
    -H "X-Vault-Token: $VAULT_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"db_name\":               \"postgres-appdb\",
        \"creation_statements\":   [$(vjson "$READER_CREATE")],
        \"revocation_statements\": [$(vjson "$REVOKE_SQL")],
        \"default_ttl\":           \"1h\",
        \"max_ttl\":               \"24h\"
    }" >/dev/null
echo "    Created: app-reader"

# ── 4. Role: app-writer (full CRUD, TTL 15m — short by design) ────────────────
# Write credentials are intentionally short-lived: each write operation should
# use fresh credentials that expire quickly, minimising the blast radius.
echo ""
echo "==> Creating role: app-writer (CRUD, TTL=15m)"

WRITER_CREATE="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT USAGE ON SCHEMA public TO \"{{name}}\"; GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO \"{{name}}\"; GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO \"{{name}}\";"

curl -sf -X POST "$VAULT_ADDR/v1/database/roles/app-writer" \
    -H "X-Vault-Token: $VAULT_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"db_name\":               \"postgres-appdb\",
        \"creation_statements\":   [$(vjson "$WRITER_CREATE")],
        \"revocation_statements\": [$(vjson "$REVOKE_SQL")],
        \"default_ttl\":           \"15m\",
        \"max_ttl\":               \"1h\"
    }" >/dev/null
echo "    Created: app-writer"

# ── 5. Vault policy ───────────────────────────────────────────────────────────
echo ""
echo "==> Creating policy: dynamic-db-policy"

DB_POLICY='path "database/creds/app-reader" { capabilities = ["read"] }
path "database/creds/app-writer"  { capabilities = ["read"] }'

curl -sf -X PUT "$VAULT_ADDR/v1/sys/policies/acl/dynamic-db-policy" \
    -H "X-Vault-Token: $VAULT_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"policy\": $(vjson "$DB_POLICY")}" >/dev/null
echo "    Created: dynamic-db-policy"

# ── 6. Kubernetes auth role ───────────────────────────────────────────────────
echo ""
echo "==> Creating Kubernetes auth role: dynamic-db-app"
curl -sf -X POST "$VAULT_ADDR/v1/auth/kubernetes/role/dynamic-db-app" \
    -H "X-Vault-Token: $VAULT_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "bound_service_account_names":      ["dynamic-db-app-sa"],
        "bound_service_account_namespaces": ["default"],
        "policies":                         ["dynamic-db-policy"],
        "ttl":                              "24h"
    }' >/dev/null
echo "    Created: dynamic-db-app -> SA dynamic-db-app-sa/default -> dynamic-db-policy"

# ── Verify ────────────────────────────────────────────────────────────────────
echo ""
echo "==> Quick verification — listing database roles:"
vapi GET database/roles

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║       Vault Dynamic DB Secrets — Configured!                 ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  DB engine  : database/                                      ║"
echo "║  Connection : postgres-appdb  ($PG_NODE_IP:$PG_PORT)       "
echo "║  Roles      : app-reader (1h) | app-writer (15m)            ║"
echo "║  Policy     : dynamic-db-policy                             ║"
echo "║  K8s role   : dynamic-db-app -> dynamic-db-app-sa/default   ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Test credentials manually:                                  ║"
echo "║    vault read database/creds/app-reader                     ║"
echo "║    vault read database/creds/app-writer                     ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Next steps:                                                 ║"
echo "║    kubectl apply -f 03-k8s-rbac.yaml                        ║"
echo "║    kubectl apply -f 04-deployment.yaml                      ║"
echo "╚══════════════════════════════════════════════════════════════╝"
