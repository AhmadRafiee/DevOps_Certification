# Vector Multi-tier (Agent → Aggregator)

Production-pattern log pipeline where lightweight **Agents** collect and forward,
and a central **Aggregator** handles all heavy processing and buffering.

```
┌──────────────────────── kind cluster (vector-multi-tier) ───────────────────────┐
│                                                                                  │
│  Node (worker)          Node (worker)          Control-plane                     │
│  ┌─────────────┐        ┌─────────────┐        ┌─────────────┐                  │
│  │ Agent       │        │ Agent       │        │ Agent       │  DaemonSet        │
│  │ • collect   │        │ • collect   │        │ • collect   │                  │
│  │ • normalize │        │ • normalize │        │ • normalize │                  │
│  └──────┬──────┘        └──────┬──────┘        └──────┬──────┘                  │
│         └───────────────────── gRPC (port 9000) ──────┘                         │
│                                       │                                          │
│                          ┌────────────▼────────────┐                            │
│                          │  Aggregator (StatefulSet)│                            │
│                          │  • parse JSON            │  disk buffer 256 MiB      │
│                          │  • enrich                │  → survives restarts       │
│                          │  • buffer (disk)         │                            │
│                          └────────────┬────────────┘                            │
│                                       │                                          │
│                          ┌────────────▼────────────┐                            │
│                          │  Loki  (StatefulSet)     │                            │
│                          └────────────┬────────────┘                            │
│                                       │                                          │
│                          ┌────────────▼────────────┐                            │
│                          │  Grafana (Deployment)    │                            │
│                          └─────────────────────────┘                            │
└──────────────────────────────────────────────────────────────────────────────────┘
       ↕ NodePort 30000             ↕ NodePort 30100
     localhost:3001               localhost:3101
      (Grafana UI)                 (Loki API)
```

## Why Multi-tier?

| Concern | Single-tier | Multi-tier |
|---------|-------------|------------|
| Agent resource usage | High (parsing + buffering) | Low (collect + forward only) |
| Loki downtime | Agents lose events or OOM | Aggregator disk-buffers → no loss |
| JSON parsing cost | On every node | Once, centrally |
| Scaling | Coupled | Scale Aggregator independently |
| Config changes | Restart all DaemonSet pods | Restart 1 Aggregator |

---

## Quick Start

```bash
cd 03.vector-multi-tier
./scripts/setup.sh

# Grafana: http://localhost:3001  (admin / admin)
```

---

## Directory Layout

```
03.vector-multi-tier/
├── kind-cluster.yml
├── scripts/
│   ├── setup.sh
│   └── teardown.sh
└── helm/
    ├── vector-agent-configmap.yml       # Agent TOML: collect → normalize → forward
    ├── vector-agent-values.yml          # Agent Helm: DaemonSet, no service
    ├── vector-aggregator-configmap.yml  # Aggregator TOML: receive → parse → buffer → Loki
    ├── vector-aggregator-values.yml     # Aggregator Helm: StatefulSet + disk persistence
    ├── loki-values.yml
    └── grafana-values.yml
```

---

## Port Reference

| Service | NodePort | Host | Notes |
|---------|----------|------|-------|
| Grafana | 30000 | 3001 | |
| Loki API | 30100 | 3101 | |
| Aggregator gRPC | 9000 | — | ClusterIP only |
| Aggregator API | 8686 | — | `kubectl port-forward` |

---

## Pipeline Detail

### Agent (DaemonSet) — `vector-agent-configmap.yml`

```
/var/log/pods/
     │
[kubernetes_logs]
     │
[normalize]     ← only: lowercase .level
     │
[vector sink]   ← gRPC → Aggregator:9000
                   memory buffer 5 000 events (drop_newest when full)
```

Agent is intentionally minimal. If the Aggregator is unavailable, agents hold
up to 5 000 events in memory, then drop the newest (oldest are preserved).

### Aggregator (StatefulSet) — `vector-aggregator-configmap.yml`

```
[vector source]  ← gRPC 0.0.0.0:9000
     │
[enrich]         ← parse JSON body, resolve .service, add .environment
     │
[loki sink]      ← disk buffer 256 MiB, block on full
                   labels: namespace / pod / container / node / level / service
```

The disk buffer means events survive an Aggregator pod restart or a brief Loki
outage — agents backpressure via the gRPC flow-control rather than dropping.

---

## Useful Commands

```bash
# Watch Agent → Aggregator flow (events/sec)
kubectl logs -n logging -l app.kubernetes.io/name=vector-agent --tail=50 \
  | grep component_sent_events_total | grep aggregator

# Watch Aggregator → Loki flow
kubectl logs -n logging -l app.kubernetes.io/name=vector-aggregator --tail=50 \
  | grep component_sent_events_total | grep loki

# Access Aggregator API
kubectl port-forward -n logging svc/vector-aggregator 8686:8686 &
curl -s http://localhost:8686/health | jq

# Check disk buffer usage
kubectl exec -n logging statefulset/vector-aggregator -- \
  du -sh /vector-data-dir/

# Scale Aggregator up (for higher throughput)
kubectl scale statefulset vector-aggregator -n logging --replicas=2

# Simulate Loki downtime — Aggregator should buffer
kubectl scale statefulset loki -n logging --replicas=0
# ... wait 30s ...
kubectl scale statefulset loki -n logging --replicas=1
# Aggregator flushes buffered events once Loki is back
```

---

## Production Checklist

- [ ] Set `replicas: 2+` on Aggregator with a load balancer service
- [ ] Increase `max_size` on disk buffer based on estimated log rate × downtime tolerance
- [ ] Add TLS between Agent and Aggregator (`tls` block on `vector` source/sink)
- [ ] Set `ENVIRONMENT` env var on the Aggregator Deployment
- [ ] Add `[sinks.loki.request.retry_max_duration_secs]` for long Loki outages
- [ ] Monitor `vector_buffer_byte_size` metric to alert before buffer fills
