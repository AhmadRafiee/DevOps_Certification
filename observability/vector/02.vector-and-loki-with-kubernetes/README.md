# Vector + Kubernetes (kind)

Log collection pipeline on a local Kubernetes cluster:
**Vector DaemonSet → Loki → Grafana**

```
┌──────────────────── kind cluster (vector-demo) ─────────────────────┐
│                                                                     │
│  Node (worker)           Node (worker)        Control-plane         │
│  ┌───────────────┐       ┌───────────────┐    ┌───────────────┐     │
│  │  Vector Agent │       │  Vector Agent │    │  Vector Agent │     │
│  │  (DaemonSet)  │       │  (DaemonSet)  │    │  (DaemonSet)  │     │
│  │               │       │               │    │               │     │
│  │ /var/log/pods │       │ /var/log/pods │    │ /var/log/pods │     │
│  └──────┬────────┘       └──────┬────────┘    └──────┬────────┘     │
│         └─────────────────────┬─┘────────────────────┘              │
│                               │  (cluster-internal DNS)             │
│                    ┌──────────▼──────────┐                          │
│                    │  Loki (StatefulSet) │  ← log storage           │
│                    │  logging namespace  │                          │
│                    └──────────┬──────────┘                          │
│                               │                                     │
│                    ┌──────────▼──────────┐                          │
│                    │ Grafana (Deployment)│  ← visualisation         │
│                    └─────────────────────┘                          │
└─────────────────────────────────────────────────────────────────────┘
     ↕ NodePort 30000        ↕ NodePort 30100
   localhost:3000           localhost:3100
     (Grafana UI)            (Loki API)

  Vector API → kubectl port-forward daemonset/vector 8686:8686
```

---

## Requirements

| Tool | Minimum version | Install |
|------|----------------|---------|
| Docker | 20+ | [docs.docker.com](https://docs.docker.com/get-docker/) |
| kind | 0.20+ | `go install sigs.k8s.io/kind@latest` |
| kubectl | 1.28+ | [kubernetes.io/docs/tasks/tools](https://kubernetes.io/docs/tasks/tools/) |
| helm | 3.12+ | `curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \| bash` |

---

## Quick Start

```bash
cd 02.vector-and-kubernetes

# Full automated setup (~3-5 min)
./scripts/setup.sh

# Open Grafana in browser
xdg-open http://localhost:3000      # Linux
open http://localhost:3000          # macOS
# User: admin  /  Password: admin
```

### Teardown

```bash
./scripts/teardown.sh
```

---

## Directory Layout

```
02.vector-and-kubernetes/
├── kind-cluster.yml                   # 3-node kind cluster (1 CP + 2 workers)
├── README.md
├── scripts/
│   ├── setup.sh                       # Full automated install
│   └── teardown.sh                    # Delete cluster & all data
└── helm/
    ├── vector-configmap.yml           # Vector pipeline config (TOML in ConfigMap)
    ├── vector-agent-values.yml        # Vector Helm values (role, RBAC, resources)
    ├── loki-values.yml                # Loki SingleBinary storage config
    └── grafana-values.yml             # Grafana with Loki datasource + dashboard
```

> **Why two Vector files?**
> Helm processes `customConfig` through its Go template engine (`tpl`), which
> misinterprets Vector's `{{ label }}` template syntax as Go template calls and
> crashes. The config lives in `vector-configmap.yml` (plain TOML, never touched
> by Helm) and is referenced via `existingConfigMaps` in the Helm values.

---

## Port Reference

| Service | NodePort | Host port | Access |
|---------|----------|-----------|--------|
| Grafana UI | 30000 | 3000 | `http://localhost:3000` |
| Loki HTTP API | 30100 | 3100 | `http://localhost:3100` |
| Vector API | — | 8686 | `kubectl port-forward daemonset/vector 8686:8686 -n logging` |

---

## Component Details

### kind Cluster — `kind-cluster.yml`

3 nodes: 1 control-plane + 2 workers.
Port mappings on the control-plane node expose Grafana and Loki to the host.
Vector runs on **all** nodes (including control-plane) via tolerations.

### Vector (DaemonSet Agent) — `helm/vector-configmap.yml`

Helm chart: `vector/vector` — `role: Agent`

One Vector pod per node. Each pod:

1. Reads all container logs from `/var/log/pods/` on the host (all namespaces)
2. Enriches with Kubernetes metadata via the API (`kubernetes.*` fields)
3. Runs the `enrich` VRL transform:
   - Parses JSON log bodies and merges fields into the event
   - Normalises `.level` / `.severity` / `.log_level` → lowercase `.level`
   - Sets `.service` from pod labels (`app.kubernetes.io/name` → `app` → container name)
4. Ships to Loki with labels: `namespace`, `pod`, `container`, `node`, `level`, `service`
5. Also ships Vector's own internal logs to Loki under `service=vector`

**Loki sink endpoint** (cluster-internal DNS):
```
http://loki.logging.svc.cluster.local:3100
```

**RBAC**: The Helm chart creates a `ClusterRole` with `list` + `watch` on
`pods`, `namespaces`, and `nodes` — cluster-wide, not namespace-scoped.

### Loki (SingleBinary) — `helm/loki-values.yml`

Helm chart: `grafana/loki` — `deploymentMode: SingleBinary`

- Single replica, filesystem storage, TSDB index (schema v13)
- Loki-canary deployed alongside for end-to-end health checks
- Retention: samples older than 7 days (`reject_old_samples_max_age: 168h`) are rejected
- Suitable for development and staging; switch to distributed + object storage for production

### Grafana — `helm/grafana-values.yml`

Helm chart: `grafana/grafana`

- Loki datasource pre-wired (auto-provisioned on startup)
- **Kubernetes Logs** dashboard auto-loaded with:
  - All Pod Logs — live tail with label filtering
  - Log Rate by Namespace — time-series per namespace
  - Log Rate by Level — time-series per level
  - Errors Only — filtered view for `error | critical | fatal`

---

## Vector Pipeline

```
/var/log/pods/ (all namespaces)
        │
[sources.kubernetes_logs]           ← reads from host filesystem
        │
        │  kubernetes.* metadata auto-enriched from K8s API
        │
[transforms.enrich]  (VRL)          ← parse JSON, normalise level, resolve service
        │
[sinks.loki]                        ← ship with namespace/pod/container/node/level/service labels
        │
  Loki HTTP API

[sources.internal_logs]
        │
[transforms.internal_meta]          ← promote metadata.level → .level
        │
[sinks.loki_self]                   ← Vector's own logs → Loki (service=vector)
```

### Loki Labels

| Label | Source | Example |
|-------|--------|---------|
| `namespace` | `kubernetes.pod_namespace` | `default`, `kube-system`, `logging` |
| `pod` | `kubernetes.pod_name` | `nginx-test-abc123` |
| `container` | `kubernetes.container_name` | `nginx` |
| `node` | `kubernetes.node_name` | `vector-demo-worker` |
| `level` | VRL-normalised from log content | `info`, `error`, `warn` |
| `service` | Pod labels or container name | `nginx`, `loki`, `grafana` |

---

## Useful Commands

### Cluster & Pods

```bash
# Overview of all pods and which node they run on
kubectl get pods --all-namespaces -o wide

# Watch Vector DaemonSet pods
kubectl get pods -n logging -l app.kubernetes.io/name=vector -o wide -w

# Tail Vector agent logs (all nodes combined)
kubectl logs -n logging -l app.kubernetes.io/name=vector -f --tail=50

# Validate Vector config without restarting
kubectl exec -n logging daemonset/vector -- vector validate --config-dir /etc/vector/
```

### Vector API

```bash
# Open a port-forward first
kubectl port-forward -n logging daemonset/vector 8686:8686 &

curl -s http://localhost:8686/health | jq
curl -s http://localhost:8686/metrics | grep "component_received_events_total"

# Check events processed per pod/namespace
kubectl logs -n logging -l app.kubernetes.io/name=vector --tail=200 \
  | grep component_received_events_total \
  | python3 -c "
import sys, json
for line in sys.stdin:
    try:
        d = json.loads(line)
        if d.get('name') == 'component_received_events_total':
            t = d.get('tags', {})
            if t.get('component_id') == 'kubernetes_logs':
                print(t.get('pod_namespace'), t.get('pod_name'), d['counter']['value'])
    except: pass
" | sort -k3 -rn | head -20
```

### Loki Queries

```bash
# List all label names
curl -s http://localhost:3100/loki/api/v1/labels | jq

# List values for a specific label
curl -s http://localhost:3100/loki/api/v1/label/namespace/values | jq
curl -s http://localhost:3100/loki/api/v1/label/pod/values | jq

# Query recent logs for a namespace
curl -s -G http://localhost:3100/loki/api/v1/query_range \
  --data-urlencode 'query={namespace="default"}' \
  --data-urlencode 'limit=20' | jq '.data.result[].values[][1]'

# Query errors across all namespaces
curl -s -G http://localhost:3100/loki/api/v1/query_range \
  --data-urlencode 'query={namespace=~".+", level="error"}' \
  --data-urlencode 'limit=20' | jq '.data.result[].values[][1]'

# Log rate per namespace (instant query)
curl -s -G http://localhost:3100/loki/api/v1/query \
  --data-urlencode 'query=sum by (namespace) (rate({namespace=~".+"}[5m]))' | jq
```

### Test Workload

```bash
# Deploy a test app — its logs appear in Grafana under namespace=default
kubectl create deployment nginx-test --image=nginx --replicas=2
kubectl expose deployment nginx-test --port=80

# Generate some traffic
kubectl run curl-test --image=curlimages/curl --restart=Never -- \
  sh -c 'for i in $(seq 1 20); do curl -s nginx-test; sleep 1; done'

# Cleanup
kubectl delete deployment nginx-test
kubectl delete service nginx-test
kubectl delete pod curl-test
```

### Config Changes

```bash
# Edit config and hot-reload (no pod restart needed)
# 1. Edit helm/vector-configmap.yml
# 2. Apply:
kubectl apply -f helm/vector-configmap.yml
# Vector watches /etc/vector/ and reloads automatically
```

---

## Manual Step-by-Step (alternative to setup.sh)

```bash
# 1. Create the kind cluster
kind create cluster --config kind-cluster.yml

# 2. Add Helm repos
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add vector  https://helm.vector.dev
helm repo update

# 3. Create namespace
kubectl create namespace logging

# 4. Install Loki
helm install loki grafana/loki \
  -n logging --values helm/loki-values.yml --wait

# 5. Apply Vector ConfigMap BEFORE installing the Helm chart
kubectl apply -f helm/vector-configmap.yml

# 6. Install Vector
helm install vector vector/vector \
  -n logging --values helm/vector-agent-values.yml --wait

# 7. Install Grafana
helm install grafana grafana/grafana \
  -n logging --values helm/grafana-values.yml --wait

# 8. Verify
kubectl get pods -n logging
curl -s http://localhost:3100/loki/api/v1/label/namespace/values | jq
```

---

## Troubleshooting

### Vector pods in CrashLoopBackOff

```bash
kubectl logs -n logging -l app.kubernetes.io/name=vector --tail=30 \
  | grep -v '^{' | grep -E "ERROR|WARN"
```

Common causes and fixes:

| Error | Cause | Fix |
|-------|-------|-----|
| `function "kubernetes" not defined` | Helm's `tpl` processed Vector's `{{ kubernetes.* }}` | Use `existingConfigMaps` — never put labels in `customConfig` |
| `Specify dataDir if you're using existingConfigMaps` | Missing `dataDir` in Helm values | Add `dataDir: /vector-data-dir` to `vector-agent-values.yml` |
| `spec.ports[0].nodePort: Forbidden` | `nodePort` on headless ClusterIP service | Use `type: ClusterIP` for Vector's service |
| `E103: unhandled fallible assignment` | `downcase()` on `any` type in VRL | Use `downcase!()` (bang) inside `is_string()` guards |
| `E651: unnecessary error coalescing` | `??` on infallible field access (`.field`) | Replace with `if is_string(.x) { .y = .x }` pattern |

### Logs not appearing in Loki

1. Check Loki labels — if `namespace` is missing, field paths are wrong:
   ```bash
   curl -s http://localhost:3100/loki/api/v1/label/namespace/values | jq
   ```

2. Check Vector is receiving events from the target namespace:
   ```bash
   kubectl logs -n logging -l app.kubernetes.io/name=vector --tail=200 \
     | grep component_received_events_total | grep <namespace>
   ```

3. Check for HTTP errors from the Loki sink:
   ```bash
   kubectl logs -n logging -l app.kubernetes.io/name=vector --tail=200 \
     | python3 -c "
   import sys,json
   for l in sys.stdin:
       try:
           d=json.loads(l)
           if 'http_client_responses' in d.get('name',''):
               print(d['tags'].get('component_id'), d['tags'].get('status'), d['counter']['value'])
       except: pass
   "
   ```

### Only one namespace visible in Loki

**Root cause**: `pod_annotation_fields` in `vector-configmap.yml` was overriding
the default `kubernetes.*` field paths. With wrong paths, all Loki `namespace`
labels resolved to empty string — Loki stored events under an empty stream that
can't be queried.

**Fix**: Do NOT set `pod_annotation_fields` in `kubernetes_logs`. Leave it unset
so Vector uses the defaults (`kubernetes.pod_namespace`, `kubernetes.pod_name`,
etc.), which match what the Loki sink labels reference.

---

## Production Checklist

- [ ] Switch Loki to distributed mode (`deploymentMode: Distributed`) with S3/GCS object storage
- [ ] Set `replication_factor: 3` in Loki for high availability
- [ ] Add Vector `[sinks.loki.buffer]` config to handle Loki backpressure
- [ ] Replace NodePort with an Ingress controller + TLS certificate for Grafana
- [ ] Rotate Grafana admin password (`adminPassword` in `grafana-values.yml`)
- [ ] Set resource `limits` on Vector pods appropriate for node size
- [ ] Configure Loki compactor retention per namespace/team using per-tenant overrides
- [ ] Add Grafana alerting rules for error rate spikes and Vector lag
- [ ] Use `extra_label_selector` in `kubernetes_logs` to exclude noisy system pods
- [ ] Add a Vector `[transforms.redact]` step to scrub secrets from log bodies before shipping
