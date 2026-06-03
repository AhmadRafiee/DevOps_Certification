#!/usr/bin/env bash
# Demo: show Vault dynamic database credentials in action.
#
# Prerequisites: all manifests applied, pod Running, port-forward active.
# Usage:  bash demo.sh [APP_URL]
# Default APP_URL: http://localhost:30808  (via NodePort on KIND node)

set -euo pipefail

APP="${1:-http://172.20.0.2:30808}"
SEP="─────────────────────────────────────────────────────────"

wait_ready() {
    echo "Waiting for app to be ready..."
    for i in $(seq 1 30); do
        curl -sf "$APP/healthz" >/dev/null 2>&1 && break
        sleep 2
        echo "  attempt $i/30..."
    done
    echo "App is up."
}

section() { echo ""; echo "$SEP"; echo "  $1"; echo "$SEP"; }

# ─────────────────────────────────────────────────────────
wait_ready

section "1. Vault token + credential cache status"
curl -s "$APP/vault/status" | python3 -m json.tool

section "2. READ — list items (uses read-only credentials)"
echo "    First call: Vault will issue a new ephemeral reader user"
curl -s "$APP/items" | python3 -m json.tool

section "3. READ again — cached credentials"
echo "    Second call within TTL: reuses the cached reader user"
curl -s "$APP/items" | python3 -m json.tool

section "4. WRITE — insert an item (fresh writer credentials every time)"
echo "    POST: Vault will issue a NEW ephemeral writer user"
curl -s -X POST "$APP/items" \
    -H "Content-Type: application/json" \
    -d '{"name":"demo-item","value":"created via Vault dynamic creds"}' \
    | python3 -m json.tool

section "5. Verify the new row is visible via read-only credentials"
curl -s "$APP/items" | python3 -m json.tool

section "6. WRITE — insert another item (second fresh writer user)"
echo "    Each write call fetches DIFFERENT ephemeral credentials from Vault"
RESULT=$(curl -s -X POST "$APP/items" \
    -H "Content-Type: application/json" \
    -d '{"name":"another-item","value":"second write operation"}')
echo "$RESULT" | python3 -m json.tool
NEW_ID=$(echo "$RESULT" | python3 -c 'import sys,json; print(json.load(sys.stdin)["id"])')

section "7. DELETE (fresh writer credentials again)"
curl -s -X DELETE "$APP/items/$NEW_ID" | python3 -m json.tool

section "8. Vault status after all operations"
curl -s "$APP/vault/status" | python3 -m json.tool

section "9. Check live ephemeral users in PostgreSQL (run from a postgres pod)"
cat <<'EOF'
  kubectl exec -it postgres-0 -- psql -U postgres -d appdb -c "
    SELECT usename, valuntil FROM pg_user WHERE usename LIKE 'v-kubernet-%' ORDER BY valuntil;
  "
  # You will see short-lived users created by Vault.
  # Writer users (TTL=15m) expire much sooner than reader users (TTL=1h).
EOF

echo ""
echo "Done!  Watch the app logs for credential issuance details:"
echo "  kubectl logs -l app=dynamic-db-app -f"
