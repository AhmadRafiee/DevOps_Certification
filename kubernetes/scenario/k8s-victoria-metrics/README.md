# VictoriaMetrics Full Monitoring Stack on kind

A complete Kubernetes monitoring setup running locally with [kind](https://kind.sigs.k8s.io/), using the [VictoriaMetrics K8s Stack](https://github.com/VictoriaMetrics/helm-charts/tree/master/charts/victoria-metrics-k8s-stack) Helm chart.

## What's included

| Component | Purpose |
|---|---|
| **VMSingle** | Long-term metrics storage (14-day retention) |
| **VMAgent** | Scrapes all targets and ships to VMSingle |
| **VMAlert** | Evaluates alerting/recording rules |
| **AlertManager** | Handles alert routing and silencing |
| **Grafana** | Dashboards with pre-built k8s views |
| **kube-state-metrics** | Kubernetes object metrics (pods, deployments, PVs…) |
| **node-exporter** | Host-level metrics (CPU, memory, disk, network) |

### Scraped components

- Kubernetes API server
- kubelet + cAdvisor
- etcd
- kube-controller-manager
- kube-scheduler
- kube-proxy
- CoreDNS
- All workloads via kube-state-metrics

## Prerequisites

| Tool | Version tested |
|---|---|
| Docker | 29.x |
| kind | v0.32.0 |
| kubectl | v1.36.x |
| helm | v3.14.x |

## Directory structure

```
k8s-victoria-metrics/
├── kind-config.yaml          # 3-node kind cluster with port mappings and registry mirrors
├── setup.sh                  # Full install: cluster + monitoring stack
├── teardown.sh               # Delete everything
├── fix-kind-components.sh    # Post-install fixes specific to kind
├── values/
│   └── vm-stack-values.yaml  # Helm values for the monitoring stack
└── registry-mirrors/         # containerd mirror configs (mounted into nodes)
    ├── quay.io/hosts.toml
    ├── registry.k8s.io/hosts.toml
    └── docker.io/hosts.toml
```

## Registry mirrors

All image pulls are redirected through internal mirrors:

| Registry | Mirror |
|---|---|
| `docker.io` | `hub.mecan.ir` |
| `quay.io` | `quay.mecan.ir` |
| `registry.k8s.io` | `k8s.mecan.ir` |

Mirrors are configured via containerd `hosts.toml` files mounted into every kind node at `/etc/containerd/certs.d`.

## Install

```bash
bash setup.sh
```

The script will:
1. Create the kind cluster (`vm-monitoring`) with 3 nodes
2. Add the VictoriaMetrics and Grafana Helm repos
3. Install the full monitoring stack via Helm
4. Run `fix-kind-components.sh` to apply kind-specific patches

Total time: ~5 minutes (excluding image pull time).

## Access

| Service | URL | Credentials |
|---|---|---|
| **Grafana** | http://localhost:30000 | `admin` / `admin123` |
| **VMSingle UI** | http://localhost:30001/vmui | — |
| **VMSingle API** | http://localhost:30001 | — |
| **AlertManager** | http://localhost:30003 | — |

## Teardown

```bash
bash teardown.sh
```

Deletes the kind cluster, removes temp directories, and cleans up the kubectl context.

## kind-specific quirks

By default, kind binds several control-plane components to `127.0.0.1`, making them unreachable from within the cluster. `fix-kind-components.sh` patches these automatically:

| Component | Fix applied |
|---|---|
| etcd | `--listen-metrics-urls` → `0.0.0.0:2381` |
| kube-controller-manager | `--bind-address` → `0.0.0.0` + allow unauthenticated `/metrics` |
| kube-scheduler | `--bind-address` → `0.0.0.0` + allow unauthenticated `/metrics` |
| kube-proxy | `metricsBindAddress` → `0.0.0.0:10249` |

The scrape scheme for etcd and kube-proxy is also patched to `http` (they don't use TLS on their metrics ports), while controller-manager and scheduler use `https` with `insecureSkipVerify: true`.

## Useful commands

```bash
# Check all monitoring pods
kubectl get pods -n monitoring

# Check scrape target health
kubectl port-forward -n monitoring svc/vmagent-vm-k8s-stack-victoria-metrics-k8s-stack 8429:8429
# then open http://localhost:8429/targets

# Check active alert rules
kubectl get vmrule -n monitoring

# Check scrape configs
kubectl get vmservicescrape -n monitoring

# Check cluster nodes
kubectl get nodes -o wide
```
