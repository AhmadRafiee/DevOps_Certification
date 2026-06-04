# Vector Observability Labs

A hands-on learning series for **Vector** — a high-performance observability data pipeline tool for collecting, transforming, and routing logs, metrics, and traces.

Each project builds on the previous one, introducing a new layer of complexity.

---

## Roadmap

```
01  Docker Compose              02  Kubernetes (kind)
────────────────────────        ──────────────────────────────
Vector                          Vector DaemonSet (all nodes)
  ├─ syslog TCP/UDP source        ├─ kubernetes_logs source
  ├─ file source                  ├─ VRL: parse + enrich
  └─ VRL: parse + enrich          └─ Loki sink
       │                               │
       ▼                               ▼
     Loki                            Loki
       │                               │
       ▼                               ▼
    Grafana                         Grafana


03  Multi-tier (K8s)            04  Metrics Pipeline (K8s)
────────────────────────        ──────────────────────────────
Agent DaemonSet                 Vector DaemonSet
  ├─ kubernetes_logs               ├─ prometheus_scrape
  ├─ lightweight normalize         │    └─ kube-state-metrics
  └─ vector sink (gRPC)            ├─ internal_metrics (Vector itself)
       │                           └─ kubernetes_logs → log_to_metric
       ▼                                └─ nginx JSON access logs
Aggregator StatefulSet                       │
  ├─ receive from agents                     ▼
  ├─ parse JSON + enrich              VictoriaMetrics
  ├─ disk buffer (256 MiB)                   │
  └─ Loki sink                              ▼
       │                               Grafana
       ▼
     Loki
       │
       ▼
    Grafana
```

---

## Projects

### 01 — Vector + Loki + Docker Compose

**Path:** `01.vector-and-loki-with-docker/`

The simplest starting point. A complete observability stack running with a single
`docker compose up -d` — no Kubernetes required.

**What you learn:**
- Vector pipeline structure: source → transform → sink
- Writing VRL (Vector Remap Language) to parse and enrich log events
- Sending syslog (TCP/UDP) and reading host log files
- Connecting Vector to Loki and visualising logs in Grafana

**Stack:**

| Service | Role | Port |
|---------|------|------|
| Vector | Collect and process logs | 9000 TCP, 9001/udp (syslog) |
| Loki | Log storage | 3100 |
| Grafana | Visualisation | 3000 |

**Quick start:**
```bash
cd 01.vector-and-loki-with-docker
docker compose up -d
# Grafana → http://localhost:3000  (admin / admin)
```

**Send a test log:**
```bash
echo '{"service":"api","level":"error","msg":"connection refused"}' \
  | nc -q1 localhost 9000
```

---

### 02 — Vector + Loki + Kubernetes (kind)

**Path:** `02.vector-and-loki-with-kubernetes/`

The same pipeline, now running on a 3-node kind cluster. Vector runs as a
DaemonSet — one pod per node — and collects logs from every namespace automatically.

**What you learn:**
- Deploying Vector with Helm on Kubernetes
- `kubernetes_logs` source: reads `/var/log/pods/` and enriches with K8s API metadata
- RBAC: ClusterRole for cross-namespace pod access
- Why `customConfig` breaks in Helm (`tpl` engine interprets `{{ }}` as Go templates)
  → solution: use `existingConfigMaps` with a plain TOML file
- Correct `kubernetes.*` field paths in VRL and Loki label templates

**Stack:**

| Service | Kind | Port |
|---------|------|------|
| Vector | DaemonSet (1 pod per node) | — |
| Loki | StatefulSet | 3100 |
| Grafana | Deployment | 3000 |

**Quick start:**
```bash
cd 02.vector-and-loki-with-kubernetes
./scripts/setup.sh
# Grafana → http://localhost:3000  (admin / admin)
```

**Verify all namespaces are collected:**
```bash
curl -s http://localhost:3100/loki/api/v1/label/namespace/values | jq
```

---

### 03 — Multi-tier: Agent → Aggregator

**Path:** `03.vector-multi-tier-with-kubernetes/`

A production-grade architecture with two Vector layers. Agents are deliberately
lightweight; the Aggregator does all the heavy lifting and owns the disk buffer.

**What you learn:**
- Separation of concerns in a log pipeline
- Vector's native gRPC protocol (`vector` source/sink) for agent-to-aggregator transport
- Disk buffer on the Aggregator: events survive pod restarts and short Loki outages
- Backpressure: agents block (not drop) when the Aggregator buffer is full
- Independent scaling of the collection layer vs. the processing layer

**Stack:**

| Service | Kind | Role |
|---------|------|------|
| vector-agent | DaemonSet | collect → normalize → forward via gRPC |
| vector-aggregator | StatefulSet + PVC | receive → parse JSON → enrich → disk-buffer → Loki |
| Loki | StatefulSet | Log storage |
| Grafana | Deployment | Visualisation |

**Quick start:**
```bash
cd 03.vector-multi-tier-with-kubernetes
./scripts/setup.sh
# Grafana → http://localhost:3001  (admin / admin)
```

**Comparison with project 02:**

| Aspect | Single-tier (02) | Multi-tier (03) |
|--------|-----------------|-----------------|
| CPU per node | Higher (full pipeline) | Lower (collect only) |
| Loki downtime tolerance | Events lost | Disk buffer absorbs the outage |
| Config change rollout | Restart every DaemonSet pod | Restart one Aggregator pod |
| Horizontal scale | Restart DaemonSet | Scale Aggregator replicas independently |

**Simulate a Loki outage:**
```bash
kubectl scale statefulset loki -n logging --replicas=0
# Aggregator buffers to disk — agents continue without dropping
kubectl scale statefulset loki -n logging --replicas=1
# Aggregator flushes the buffer automatically on reconnect
```

---

### 04 — Metrics Pipeline

**Path:** `04.vector-metrics-pipeline-with-kubernetes/`

Vector as a **metrics** pipeline, not just a log pipeline. This project shows
that Vector is a single agent capable of handling all three observability signals:
logs, metrics, and (with the right sources) traces.

#### Why metrics matter here

In the previous three projects Vector only dealt with **logs** — unstructured
text events stored in Loki and queried with LogQL.

Metrics are a fundamentally different signal:

| Signal | Shape | Storage | Query language | Best for |
|--------|-------|---------|----------------|----------|
| Logs | Timestamped strings | Loki | LogQL | Debugging, audit trails |
| Metrics | Timestamped numbers + labels | Prometheus / VictoriaMetrics | PromQL | Dashboards, alerting, SLOs |

Running both through the same Vector agent means one binary, one config
format (TOML + VRL), and one set of operational concerns instead of deploying
a separate Prometheus Agent or Telegraf alongside Vector.

#### Two ways Vector produces metrics

**1. `prometheus_scrape` source — pull existing `/metrics` endpoints**

Vector periodically scrapes Prometheus-format endpoints from services already
running in the cluster (Grafana, VictoriaMetrics itself, kube-state-metrics).
No code change needed in those services.

**2. `log_to_metric` transform — derive metrics from logs**

nginx is configured to write structured JSON access logs:
```json
{"method":"GET","uri":"/","status":200,"bytes":512,"duration":0.003}
```

Vector parses each log line and emits Prometheus-style counters and histograms
*without any changes to nginx*. This is the key insight: applications that
already log in a structured format can expose metrics for free.

| Derived metric | Type | Labels |
|----------------|------|--------|
| `app_http_requests_total` | counter | namespace, service, method, status |
| `app_http_response_bytes` | histogram | namespace, service |
| `app_http_request_duration_seconds` | histogram | namespace, service, method |

**Stack:**

| Service | Kind | Port |
|---------|------|------|
| Vector | DaemonSet | — |
| kube-state-metrics | Deployment | 8080 (ClusterIP) |
| nginx-demo | Deployment + sidecar traffic generator | — |
| VictoriaMetrics | StatefulSet | 8428 |
| Grafana | Deployment | 3002 |

> Loki is **not** part of this project. All data flows to VictoriaMetrics
> and is visualised with PromQL dashboards in Grafana.

**Quick start:**
```bash
cd 04.vector-metrics-pipeline-with-kubernetes
./scripts/setup.sh
# Grafana          → http://localhost:3002  (admin / admin)
# VictoriaMetrics  → http://localhost:8428
```

**Verify metrics are flowing:**
```bash
# All metric names stored in VictoriaMetrics
curl -s 'http://localhost:8428/api/v1/label/__name__/values' | jq '.data[]' | grep -E "app_|kube_|vector_"

# nginx request rate from log_to_metric
curl -s 'http://localhost:8428/api/v1/query?query=rate(app_http_requests_total[2m])' | jq

# HTTP error rate (4xx + 5xx)
curl -s 'http://localhost:8428/api/v1/query?query=rate(app_http_requests_total{status=~"[45].."}[2m])' | jq

# Pod count from kube-state-metrics
curl -s 'http://localhost:8428/api/v1/query?query=count(kube_pod_status_phase{phase="Running"})' | jq
```

---

## Summary comparison

| | 01 | 02 | 03 | 04 |
|--|----|----|----|----|
| **Environment** | Docker Compose | Kubernetes | Kubernetes | Kubernetes |
| **Signal** | Logs | Logs | Logs | Metrics |
| **Vector role** | Single agent | DaemonSet | Agent + Aggregator | DaemonSet |
| **Log storage** | Loki | Loki | Loki | — |
| **Metric storage** | — | — | — | VictoriaMetrics |
| **Buffer** | Memory | Memory | Disk (Aggregator) | Memory |
| **Prerequisites** | Docker | kind, kubectl, helm | kind, kubectl, helm | kind, kubectl, helm |

---

## Prerequisites

```bash
# Docker  →  https://docs.docker.com/get-docker/

# kind
go install sigs.k8s.io/kind@latest

# kubectl  →  https://kubernetes.io/docs/tasks/tools/

# helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

---

## Lessons learned across all projects

Real problems encountered while building these labs — and their fixes.

**1. Helm's template engine conflicts with Vector's `{{ }}` syntax**

Helm processes `customConfig` through `tpl`, which treats `{{ kubernetes.pod_namespace }}`
as a Go template function call and crashes.

Fix: put the Vector config in a separate Kubernetes ConfigMap (plain TOML,
never touched by Helm) and reference it with `existingConfigMaps` in the Helm values.
Always add `dataDir` alongside `existingConfigMaps` or the chart will error.

**2. Do not set `pod_annotation_fields` in `kubernetes_logs`**

This option overrides the field paths where Kubernetes metadata is stored.
Setting it without the `kubernetes.` prefix stores metadata at top-level fields
(`.pod_namespace`) while Loki label templates expect `{{ kubernetes.pod_namespace }}`,
causing every namespace label to be empty — logs are pushed to Loki but are
never queryable.

Fix: omit `pod_annotation_fields` entirely. Vector's defaults (`kubernetes.*` paths)
match the label templates.

**3. VRL has strict type rules**

- `??` (error coalescing) only works on *fallible* expressions like `string()` — not on plain field access (`.field`)
- `downcase()` on type `any` is a compile error — use `downcase!()` inside an `if is_string()` guard
- `else if` must follow the closing `}` on the same line
- `merge(target, source)` requires an `is_object(source)` guard to be infallible

**4. The Vector Docker image does not load your TOML file by default**

The official image looks for `vector.yaml`. If your config is `vector.toml`,
override the command explicitly:
```yaml
command: ["--config", "/etc/vector/vector.toml"]
```

**5. Grafana `init-chown-data` crashes in kind**

kind's `local-path-provisioner` mounts volumes as root. The Grafana init container
that runs `chown` on the data directory fails without elevated privileges.

Fix: add `initChownData: { enabled: false }` to the Grafana Helm values.

---

## References

- [Vector Docs](https://vector.dev/docs/)
- [VRL Reference](https://vrl.dev/)
- [Vector Helm Chart](https://helm.vector.dev/)
- [Loki Docs](https://grafana.com/docs/loki/latest/)
- [VictoriaMetrics Docs](https://docs.victoriametrics.com/)
- [kube-state-metrics](https://github.com/kubernetes/kube-state-metrics)
