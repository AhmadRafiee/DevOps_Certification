# Vector Logging Stack

A production-ready log aggregation pipeline built with **Vector → Loki → Grafana**.

```
App / Host logs
      │
      ▼
 ┌─────────┐  parse & enrich   ┌──────┐   store   ┌─────────┐
 │  Vector │ ────────────────► │ Loki │ ◄──────── │ Grafana │
 └─────────┘                   └──────┘           └─────────┘
```

---

## Services

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| **vector** | `timberio/vector:0.41.0-alpine` | 8686, 9000, 9001/udp | Log collection & routing |
| **loki** | `grafana/loki:3.0.0` | 3100 | Log storage |
| **grafana** | `grafana/grafana:11.0.0` | 3000 | Log visualisation |

---

## Quick Start

```bash
# 1. Clone / enter the directory
cd 01.setup

# 2. Start the stack
docker compose up -d

# 3. Check all services are healthy
docker compose ps

# 4. Open Grafana
#    URL:      http://localhost:3000
#    User:     admin
#    Password: admin
```

> Change the Grafana password in `compose.yml` (`GF_SECURITY_ADMIN_PASSWORD`) before deploying to production.

---

## Directory Layout

```
01.setup/
├── compose.yml
├── README.md
└── config/
    ├── vector.toml                          # Vector pipeline config
    ├── loki.yml                             # Loki storage config
    └── grafana/
        └── provisioning/
            ├── datasources/
            │   └── loki.yml                # Auto-wires Loki as default datasource
            └── dashboards/
                ├── provider.yml            # Dashboard loader
                └── logs-overview.json      # Pre-built dashboard
```

---

## Sending Logs to Vector

### Syslog (TCP)

```bash
# One-liner test
echo "<34>$(date -u +%FT%TZ) myapp[1234]: Hello from syslog" \
  | nc -q1 localhost 9000
```

### Syslog (UDP)

```bash
echo "<34>$(date -u +%FT%TZ) myapp[1234]: Hello UDP" \
  | nc -u -q1 localhost 9001
```

### JSON structured log (via TCP)

```bash
echo '{"message":"order placed","service":"shop","level":"info","order_id":42}' \
  | nc -q1 localhost 9000
```

### From another Docker container

Add the container to the `logging_network` and point its log driver or sidecar at `vector:9000`.

```yaml
# In the application's compose.yml
services:
  my-app:
    networks:
      - logging_network
    logging:
      driver: syslog
      options:
        syslog-address: "tcp://vector:9000"
        tag: "my-app"

networks:
  logging_network:
    external: true
    name: logging_network
```

---

## Vector Pipeline

```
syslog_tcp ──┐
syslog_udp ──┤──► parse_json ──► add_labels ──► loki (sink)
host_logs  ──┘

internal_logs ──────────────────────────────► loki_internal (sink)
internal_metrics ───────────────────────────► console (sink)
```

| Stage | What it does |
|-------|-------------|
| `parse_json` | Parses `.message` as JSON when possible; normalises `.level` |
| `add_labels` | Adds `environment` label from `$ENVIRONMENT` env var |
| `loki` sink | Ships to Loki with labels: `level`, `service`, `environment`, `host` |

To change routing or add new sources/sinks, edit `config/vector.toml` — Vector reloads automatically when `VECTOR_WATCH_CONFIG=true`.

---

## Grafana Dashboards

The **Logs Overview** dashboard is provisioned automatically and includes:

- **All Logs** panel — live tail with label filtering
- **Log Rate by Service** — time-series per service
- **Log Rate by Level** — time-series per level
- **Errors Only** — filtered view for `error / critical / fatal`

Open it at: **Dashboards → Logging → Logs Overview**

---

## Ports Reference

| Port | Protocol | Description |
|------|----------|-------------|
| `3000` | HTTP | Grafana UI |
| `3100` | HTTP | Loki API |
| `8686` | HTTP | Vector API (`/health`, `/metrics`, `/graphql`) |
| `9000` | TCP | Syslog TCP input |
| `9001` | UDP | Syslog UDP input |

---

## Environment Variables

Set these in `compose.yml` under the `vector` service:

| Variable | Default | Description |
|----------|---------|-------------|
| `VECTOR_LOG` | `info` | Vector log verbosity (`trace / debug / info / warn / error`) |
| `VECTOR_WATCH_CONFIG` | `true` | Hot-reload config on file change |
| `ENVIRONMENT` | `production` | Label attached to every log line |

---

## Useful Commands

```bash
# Tail Vector logs
docker compose logs -f vector

# Validate the Vector config without restarting
docker compose exec vector vector validate /etc/vector/vector.toml

# Query Loki directly
curl -G http://localhost:3100/loki/api/v1/query \
  --data-urlencode 'query={service="myapp"}' | jq

# Check Vector internal stats
curl -s http://localhost:8686/health | jq

# Stop & remove all containers + volumes
docker compose down -v
```

---

## Production Checklist

- [ ] Change `GF_SECURITY_ADMIN_PASSWORD` to a strong secret (or use Grafana SSO)
- [ ] Set `ENVIRONMENT` label (`staging`, `production`, …)
- [ ] Configure `reject_old_samples_max_age` in `loki.yml` to match your retention policy
- [ ] Mount a named volume or external storage for `loki_data` for durability
- [ ] Add TLS termination (nginx/Traefik) in front of Grafana
- [ ] Restrict port exposure — only expose `3000` externally; keep `3100` / `8686` internal
