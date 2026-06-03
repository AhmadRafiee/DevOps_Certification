# Dynamic Database Credentials with Vault

This scenario demonstrates **Vault's Database Secrets Engine** — an app that receives
ephemeral PostgreSQL credentials on demand, with different privilege levels for read vs write.

---

## How it works

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          Kubernetes Cluster                                  │
│                                                                             │
│  ┌──────────────────────┐        ┌──────────────────────────────────────┐  │
│  │   dynamic-db-app     │        │            Vault (external)          │  │
│  │   (Flask / Python)   │        │                                      │  │
│  │                      │──(1)──▶│  auth/kubernetes/login               │  │
│  │  GET  /items         │◀─token─│                                      │  │
│  │                      │        │                                      │  │
│  │  ┌─────────────────┐ │──(2)──▶│  database/creds/app-reader           │  │
│  │  │  READ path      │ │◀─creds─│  → CREATE ROLE v-xxx  SELECT only    │  │
│  │  │  cached ~1h     │ │        │                                      │  │
│  │  └────────┬────────┘ │        │                                      │  │
│  │           │          │        │                                      │  │
│  │  ┌─────────────────┐ │──(3)──▶│  database/creds/app-writer           │  │
│  │  │  WRITE path     │ │◀─creds─│  → CREATE ROLE v-yyy  CRUD           │  │
│  │  │  NEVER cached   │ │        │                                      │  │
│  │  └────────┬────────┘ │        └──────────────────────────────────────┘  │
│  │           │          │                                                   │
│  └─────┬─────┴──────────┘                                                  │
│        │  SELECT / INSERT / DELETE                                          │
│        ▼                                                                    │
│  ┌─────────────┐                                                            │
│  │  PostgreSQL │  ← ephemeral user v-xxx (SELECT)  expires in ~1h          │
│  │   (appdb)   │  ← ephemeral user v-yyy (CRUD)    expires in ~15m         │
│  └─────────────┘                                                            │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Why two roles?

| Role | SQL privileges | Default TTL | Caching in app |
|------|---------------|-------------|----------------|
| `app-reader` | `SELECT` only | **1 h** | Yes — reused until 90% TTL |
| `app-writer` | `SELECT, INSERT, UPDATE, DELETE` + sequences | **15 min** | **Never** — fresh per write call |

Writer credentials are short-lived and never cached so that:
- A leaked writer credential expires quickly
- Each write operation explicitly proves it has current authorisation from Vault
- Vault's audit log shows exactly when write access was requested

---

## Prerequisites

- Vault running (from `01.setup/`)
- Kubernetes cluster with Vault Agent Injector (from `02.k8s-integration/`)
- Kubernetes auth method already configured (`02.k8s-integration/01-vault-setup.sh` ran)

---

## Setup

### Step 1 — Deploy PostgreSQL

```bash
kubectl apply -f 01-postgres.yaml

# Wait until ready
kubectl rollout status statefulset/postgres
```

### Step 2 — Configure Vault Database Engine

```bash
# The script auto-detects the KIND node IP for the PostgreSQL NodePort (30432).
# Override with: export PG_NODE_IP=<your-node-ip>
bash 02-vault-db-engine-setup.sh

# Verify credentials work manually
VAULT_ADDR=http://172.18.0.2:8200 VAULT_TOKEN=myroot \
  curl -s http://172.18.0.2:8200/v1/database/creds/app-reader \
    -H "X-Vault-Token: myroot" | python3 -m json.tool
```

### Step 3 — Create the ServiceAccount

```bash
kubectl apply -f 03-k8s-rbac.yaml
```

### Step 4 — Deploy the app

```bash
kubectl apply -f 04-deployment.yaml
kubectl rollout status deployment/dynamic-db-app
```

### Step 5 — Run the demo

```bash
bash demo.sh
```

---

## Exploring the scenario manually

```bash
# Port-forward for easier access (optional — NodePort 30808 also works)
kubectl port-forward svc/dynamic-db-app 8080:8080 &

# READ — uses read-only credentials (cached)
curl http://localhost:8080/items

# WRITE — uses fresh write credentials each time
curl -X POST http://localhost:8080/items \
  -H "Content-Type: application/json" \
  -d '{"name":"test","value":"dynamic credentials demo"}'

# Check Vault token + cache state
curl http://localhost:8080/vault/status | python3 -m json.tool

# See the ephemeral users Vault created in PostgreSQL
kubectl exec -it postgres-0 -- psql -U postgres -d appdb -c "
  SELECT usename, valuntil FROM pg_user WHERE usename LIKE 'v-kubernet-%' ORDER BY valuntil;
"

# Watch the app logs to see Vault interactions in real time
kubectl logs -l app=dynamic-db-app -f
```

**Example log output:**
```
10:01:15  INFO     Vault login OK  token_ttl=86400s
10:01:15  INFO     Vault issued  role=app-reader    user=v-kubernet-app-reader-abc123  ttl=3600s
10:01:20  INFO     Reader creds from cache  user=v-kubernet-app-reader-abc123
10:01:25  INFO     Vault issued  role=app-writer    user=v-kubernet-app-writer-xyz789  ttl=900s
10:01:30  INFO     Vault issued  role=app-writer    user=v-kubernet-app-writer-mnop456 ttl=900s
                                                    ^^^^ different user for each write!
```

---

## Verifying the privilege boundary

Connect to PostgreSQL directly as the ephemeral reader user and confirm it cannot write:

```bash
# Get a reader credential manually
READER=$(curl -s http://172.18.0.2:8200/v1/database/creds/app-reader \
  -H "X-Vault-Token: myroot")
RUSER=$(echo $READER | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d["data"]["username"])')
RPASS=$(echo $READER | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d["data"]["password"])')

# Try to INSERT with a read-only user — this should FAIL with permission denied
kubectl exec -it postgres-0 -- psql \
  "postgresql://${RUSER}:${RPASS}@localhost:5432/appdb" \
  -c "INSERT INTO items (name) VALUES ('should-fail');"
# ERROR:  permission denied for table items  ✓
```

---

## Cleanup

```bash
kubectl delete -f 04-deployment.yaml
kubectl delete -f 03-k8s-rbac.yaml
kubectl delete -f 01-postgres.yaml

# Remove Vault configuration
VAULT_ADDR=http://172.18.0.2:8200 VAULT_TOKEN=myroot
curl -X DELETE http://172.18.0.2:8200/v1/sys/mounts/database -H "X-Vault-Token: myroot"
curl -X DELETE http://172.18.0.2:8200/v1/sys/policies/acl/dynamic-db-policy -H "X-Vault-Token: myroot"
curl -X DELETE http://172.18.0.2:8200/v1/auth/kubernetes/role/dynamic-db-app -H "X-Vault-Token: myroot"
```
