# Vector Metrics Pipeline

Vector as a unified **metrics** pipeline:
scrape Prometheus endpoints + convert logs to metrics → VictoriaMetrics → Grafana.

```
┌─────────────────── kind cluster (vector-metrics) ────────────────────┐
│                                                                      │
│  Sources                    Vector (DaemonSet)         Sinks         │
│  ──────────────────────     ───────────────────        ───────────── │
│                                                                      │
│  kube-state-metrics ──────► filter_ksm ──────────────────────────┐   │
│                                                                  │   │
│  Loki /metrics ────────────► add_cluster_label ──────────────────┤   │
│  Grafana /metrics ─────────►                                     ├──►│ VictoriaMetrics
│  VictoriaMetrics /metrics ─►                                     │   │ (remote_write)
│                                                                  │   │
│  kubernetes_logs ──────────► parse_access_log                    │   │
│  (nginx JSON logs)              └──► log_to_metric ──────────────┘   │
│                                      (counter, histogram)            │
│                                                                      │
│  internal_metrics ─────────► (included in add_cluster_label)         │
└──────────────────────────────────────────────────────────────────────┘

VictoriaMetrics → Grafana → dashboards
```

---

## What this demonstrates

| Feature | How |
|---------|-----|
| `prometheus_scrape` | Pulls /metrics from Loki, Grafana, kube-state-metrics, VictoriaMetrics |
| `log_to_metric` | Converts nginx JSON access logs → `http_requests_total` counter + histograms |
| `filter` transform | Drops noisy kube-state-metrics series before storage |
| `prometheus_remote_write` | Sends all metrics to VictoriaMetrics |
| `internal_metrics` | Exposes Vector's own pipeline health as metrics |

---

## Quick Start

```bash
cd 05.vector-metrics-pipeline
./scripts/setup.sh

# Grafana:         http://localhost:3002  (admin / admin)
# VictoriaMetrics: http://localhost:8428
```

---

## Directory Layout

```
05.vector-metrics-pipeline/
├── kind-cluster.yml
├── scripts/
│   ├── setup.sh
│   └── teardown.sh
└── helm/
    ├── vector-configmap.yml            # Vector TOML pipeline config
    ├── vector-values.yml               # Vector Helm values
    ├── victoriametrics-values.yml      # VictoriaMetrics single binary
    ├── kube-state-metrics-values.yml   # kube-state-metrics
    ├── grafana-values.yml              # Grafana + pre-built dashboard
    └── nginx-demo.yml                  # Test nginx app with JSON access logs
```

---

## Port Reference

| Service | NodePort | Host | Notes |
|---------|----------|------|-------|
| Grafana | 30000 | 3002 | |
| VictoriaMetrics | 30428 | 8428 | Prometheus-compatible API |
| Loki | 30100 | 3103 | Raw log storage |
| Vector API | — | — | `kubectl port-forward` |

---

## Metrics Sources

### prometheus_scrape — existing /metrics endpoints

Vector scrapes these endpoints every 30 seconds:

| Endpoint | What you get |
|----------|-------------|
| `loki:3100/metrics` | log ingestion rate, stream count, chunk size |
| `grafana:3000/metrics` | dashboard load times, active sessions |
| `victoria-metrics:8428/metrics` | storage utilization, query rate |
| `kube-state-metrics:8080/metrics` | pod/deployment/node state |

### log_to_metric — nginx access logs → Prometheus counters

nginx is configured to write JSON access logs:
```json
{"time":"...","method":"GET","uri":"/","status":200,"bytes":42,"duration":0.001}
```

Vector parses each log line and emits:

| Metric | Type | Labels |
|--------|------|--------|
| `app_http_requests_total` | counter | namespace, service, method, status |
| `app_http_response_bytes` | histogram | namespace, service |
| `app_http_request_duration_seconds` | histogram | namespace, service, method |

These metrics are **derived entirely from logs** — the application doesn't need
a Prometheus client or `/metrics` endpoint.

---

## Grafana Dashboard

**Vector Metrics Pipeline** dashboard includes:

- HTTP Requests/sec by Status code
- HTTP Error Rate (4xx + 5xx) by service
- Vector Events Processed/sec by component
- Pod Restarts (from kube-state-metrics)
- Running Pods count + Unavailable Deployments stat
- Loki ingestion rate

---

## Useful Commands

```bash
# List all metric names stored in VictoriaMetrics
curl -s 'http://localhost:8428/api/v1/label/__name__/values' | jq '.data[]' | head -30

# Query nginx request rate
curl -s 'http://localhost:8428/api/v1/query?query=rate(app_http_requests_total[2m])' | jq

# Query error rate
curl -s 'http://localhost:8428/api/v1/query?query=rate(app_http_requests_total{status=~"[45].."}[2m])' | jq

# Check Vector is scraping correctly
kubectl port-forward -n monitoring daemonset/vector 8686:8686 &
curl -s http://localhost:8686/metrics | grep component_received_events_total | grep prometheus

# Check kube-state-metrics directly
kubectl port-forward -n monitoring svc/kube-state-metrics 8080:8080 &
curl -s http://localhost:8080/metrics | grep kube_pod_status_phase | head -5

# Add a bad-status pod to generate error metrics
kubectl run fail-pod --image=nginx:alpine --restart=Never \
  -- sh -c 'exit 1'
# → kube_pod_status_phase{phase="Failed"} should increase
```

---

## Extending the Pipeline

### Add a new scrape target

Edit `helm/vector-configmap.yml`, add the endpoint to `[sources.prometheus_scrape]`:
```toml
endpoints = [
  "http://loki.logging.svc.cluster.local:3100/metrics",
  "http://my-app.default.svc.cluster.local:9090/metrics",   # ← new
]
```
Apply with `kubectl apply -f helm/vector-configmap.yml`.

### Add a new log-to-metric conversion

Add a new `[[transforms.log_to_metric.metrics]]` block:
```toml
[[transforms.log_to_metric.metrics]]
type      = "counter"
field     = "query_duration_ms"
name      = "db_query_duration_ms_total"
namespace = "app"
  [transforms.log_to_metric.metrics.tags]
  db      = "{{db_name}}"
  service = "{{kubernetes.pod_name}}"
```

---

## Production Checklist

- [ ] Replace VictoriaMetrics single with the cluster chart for HA storage
- [ ] Set scrape intervals per-source based on metric freshness requirements
- [ ] Add `[transforms.remap]` to drop PII from log lines before `log_to_metric`
- [ ] Configure VictoriaMetrics retention and storage size based on cardinality
- [ ] Add Vector alerting via `sinks.http` to Alertmanager for critical metrics
- [ ] Set `CLUSTER_NAME` and `ENVIRONMENT` env vars on the Vector DaemonSet
