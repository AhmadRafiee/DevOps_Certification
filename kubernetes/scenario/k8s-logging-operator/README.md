# Kubernetes Logging Stack on Kind

A local Kubernetes logging stack using **kube-logging/logging-operator**, **Fluentd**, **Fluent Bit**, **Elasticsearch**, and **Kibana** — deployed on a [kind](https://kind.sigs.k8s.io/) cluster with offline-friendly image mirrors.

## Architecture

```
Pods (all namespaces)
  └─► Fluent Bit (DaemonSet)        — collects logs from each node
        └─► Fluentd (StatefulSet)   — aggregates, filters, buffers
              └─► Elasticsearch     — stores logs
                    └─► Kibana      — visualises logs (http://localhost:5601)
```

The **logging-operator** manages Fluentd and Fluent Bit via three CRDs:

| CRD | Purpose |
|-----|---------|
| `Logging` | Defines Fluentd + Fluent Bit daemonsets and their images |
| `Output` | Where to send logs (Elasticsearch in this setup) |
| `Flow` | Which pods to collect from and what filters to apply |

## Prerequisites

| Tool | Version tested |
|------|----------------|
| Docker | 24+ |
| kind | v0.23+ |
| kubectl | v1.32+ |
| helm | v3.14+ |

## Quick Start

```bash
./setup.sh
```

The script:
1. Creates a kind cluster (`logging-demo`) with port mappings
2. Installs `kube-logging/logging-operator` via Helm (chart 4.2.3)
3. Deploys Elasticsearch + Kibana
4. Applies `Logging`, `Output`, and `Flow` CRDs
5. Deploys a `log-generator` demo app that emits JSON logs every 2 seconds

## Accessing the Stack

| Service | URL | Notes |
|---------|-----|-------|
| Kibana | http://localhost:5601 | |
| Elasticsearch | http://localhost:9200 | |

> **Tip — if Kibana is unreachable**, use port-forward as a fallback:
> ```bash
> kubectl port-forward svc/kibana 5601:5601 -n logging
> ```

## Viewing Logs in Kibana

1. Open http://localhost:5601
2. Go to **Stack Management → Data Views → Create data view**
3. Set **Index pattern** to `kubernetes-logs*` and **Timestamp field** to `@timestamp`
4. Save, then open **Discover** and select the `kubernetes-logs` data view

## Image Mirrors

All images are pulled from internal mirrors (no public internet required):

| Mirror | Proxies |
|--------|---------|
| `hub.mecan.ir` | Docker Hub |
| `github.mecan.ir` | ghcr.io |
| `k8s.mecan.ir` | registry.k8s.io |

Full image list: [images.txt](images.txt)

## File Structure

```
.
├── setup.sh               # One-shot cluster bootstrap script
├── cleanup.sh             # Tear down the cluster and clean up
├── kind-cluster.yaml      # Kind cluster config (3 nodes, port mappings)
├── images.txt             # All images used, with mirror addresses
├── README.md
└── manifests/
    ├── elasticsearch.yaml  # Elasticsearch StatefulSet + Services
    ├── kibana.yaml         # Kibana Deployment + NodePort Service
    ├── logging-config.yaml # Logging / Output / Flow CRDs
    └── demo-app.yaml       # log-generator demo Deployment
```

## Useful Commands

```bash
# Check all pods
kubectl get pods -n logging

# Watch Fluentd logs
kubectl logs -n logging -l app=fluentd -f

# Watch Fluent Bit logs
kubectl logs -n logging -l app=fluent-bit -f

# Check operator logs
kubectl logs -n logging -l app.kubernetes.io/name=logging-operator -f

# Count logs in Elasticsearch
kubectl exec -n logging elasticsearch-0 -- \
  curl -s 'http://localhost:9200/kubernetes-logs/_count' | python3 -m json.tool
```

## Teardown

```bash
./cleanup.sh
```

Removes the kind cluster, Helm repo, and temp files.
