# Level 22 — Prometheus & Grafana Monitoring

### Requirements:
  - **Vault Service is Running** from level 15
  - **Vault Address:** `https://vault.lab.mecan.ir`
  - **Auth:** Root token `your-root-token-here` (dev mode only)
  - **Tools:** install `jq` command

---

## Overview

Vault exposes operational metrics via `/v1/sys/metrics`. Prometheus scrapes
these metrics, and Grafana visualizes them. This gives you real-time visibility
into cluster health, request rates, lease counts, and performance.

---

## 22.1 Vault Metrics Endpoint

The metrics endpoint works in both dev mode and production mode.
In production mode, enable prometheus metrics via telemetry config:

```hcl
telemetry {
  prometheus_retention_time = "30s"
  disable_hostname          = true
}
```

Test the endpoint:
```bash
echo ROOT_TOKEN=your-root-token-here
curl https://vault.lab.mecan.ir/v1/sys/metrics?format=prometheus \
  -H "X-Vault-Token: $ROOT_TOKEN" | head -10
```

Response (Prometheus text format):
```
# HELP go_gc_duration_seconds ...
# TYPE go_gc_duration_seconds summary
go_gc_duration_seconds{quantile="0"} 4.6848e-05
vault_core_unsealed{cluster="..."} 1
vault_expire_num_leases 2
```

---

## 22.2 Add to compose.yml

```yaml
prometheus:
  image: prom/prometheus:v2.51.0
  container_name: vault_prometheus
  networks:
    - infra-network
  ports:
    - "9090:9090"
  volumes:
    - ./monitoring/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
    - ./monitoring/prometheus/vault-token:/etc/prometheus/vault-token:ro
  command:
    - --config.file=/etc/prometheus/prometheus.yml
    - --storage.tsdb.retention.time=7d

grafana:
  image: grafana/grafana:10.4.0
  container_name: vault_grafana
  networks:
    - infra-network
  ports:
    - "3000:3000"
  environment:
    GF_SECURITY_ADMIN_PASSWORD: admin
  volumes:
    - ./monitoring/grafana/provisioning:/etc/grafana/provisioning:ro
```

---

## 22.3 Prometheus Configuration

`monitoring/prometheus/prometheus.yml`:

```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: vault-dev
    metrics_path: /v1/sys/metrics
    params:
      format: [prometheus]
    scheme: http
    authorization:
      credentials: myroot        # or use credentials_file for production
    static_configs:
      - targets: [172.19.0.2:8200]   # use internal IP, not domain
        labels:
          instance: vault-dev

  - job_name: vault-autounseal
    metrics_path: /v1/sys/metrics
    params:
      format: [prometheus]
    scheme: http
    authorization:
      credentials: hvs.XXXX
    static_configs:
      - targets: [172.19.0.3:8200]
        labels:
          instance: vault-autounseal
```

**Important:** Use internal Docker network IPs, not external domain names.
Prometheus runs inside Docker and cannot resolve external domains to internal IPs.

---

## 22.4 Grafana Datasource Provisioning

`monitoring/grafana/provisioning/datasources/prometheus.yml`:

```yaml
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
```

---

## 22.5 Key Vault Metrics

| Metric | Meaning |
|---|---|
| `vault_core_unsealed` | 1 = unsealed, 0 = sealed |
| `vault_core_active` | 1 = this node is leader |
| `vault_expire_num_leases` | Number of active leases |
| `vault_runtime_num_goroutines` | Go goroutines (memory health) |
| `vault_runtime_alloc_bytes` | Memory allocated |
| `vault_core_mount_table_num_entries` | Mounted secrets engines |
| `vault_barrier_get` | Latency of barrier reads |
| `vault_barrier_put` | Latency of barrier writes |
| `vault_cache_hit` | Cache effectiveness |

---

## 22.6 Useful PromQL Queries

```promql
# Is Vault unsealed?
vault_core_unsealed == 1

# Number of leases by instance
vault_expire_num_leases

# Vault request rate (last 5m)
rate(vault_core_response_status_code_total[5m])

# Barrier read latency (p99)
histogram_quantile(0.99, rate(vault_barrier_get_bucket[5m]))

# Memory usage
vault_runtime_alloc_bytes / 1024 / 1024  # in MB
```

---

## 22.7 Test Results

| Test | Result |
|---|---|
| Prometheus scrapes vault-dev | ✅ target=up |
| Prometheus scrapes vault-autounseal | ✅ target=up |
| `vault_core_unsealed=1` for both instances | ✅ |
| `vault_expire_num_leases` shows active leases | ✅ |
| Grafana datasource → Prometheus connected | ✅ |

---

## API Reference

| Operation | Method | Path |
|---|---|---|
| Metrics (Prometheus format) | GET | `/v1/sys/metrics?format=prometheus` |
| Metrics (JSON format) | GET | `/v1/sys/metrics` |
