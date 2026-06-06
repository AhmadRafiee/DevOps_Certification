#!/usr/bin/env bash
# Fix kind-specific issues for VictoriaMetrics monitoring
# Run automatically from setup.sh after helm install

set -euo pipefail

CTRL_PLANE="vm-monitoring-control-plane"
NS="monitoring"
RELEASE="vm-k8s-stack"

# ─── 1. kube-controller-manager ─────────────────────────────
echo "[1/4] Patching kube-controller-manager..."
docker exec "$CTRL_PLANE" sed -i \
  's/--bind-address=127\.0\.0\.1/--bind-address=0.0.0.0/' \
  /etc/kubernetes/manifests/kube-controller-manager.yaml

docker exec "$CTRL_PLANE" grep -q "authorization-always-allow-paths" \
  /etc/kubernetes/manifests/kube-controller-manager.yaml || \
  docker exec "$CTRL_PLANE" sed -i \
    '/--bind-address=0\.0\.0\.0/a\    - --authorization-always-allow-paths=/metrics,/healthz,/readyz,/livez' \
    /etc/kubernetes/manifests/kube-controller-manager.yaml

# ─── 2. kube-scheduler ──────────────────────────────────────
echo "[2/4] Patching kube-scheduler..."
docker exec "$CTRL_PLANE" sed -i \
  's/--bind-address=127\.0\.0\.1/--bind-address=0.0.0.0/' \
  /etc/kubernetes/manifests/kube-scheduler.yaml

docker exec "$CTRL_PLANE" grep -q "authorization-always-allow-paths" \
  /etc/kubernetes/manifests/kube-scheduler.yaml || \
  docker exec "$CTRL_PLANE" sed -i \
    '/--bind-address=0\.0\.0\.0/a\    - --authorization-always-allow-paths=/metrics,/healthz,/readyz,/livez' \
    /etc/kubernetes/manifests/kube-scheduler.yaml

# ─── 3. etcd metrics endpoint ───────────────────────────────
echo "[3/4] Patching etcd..."
docker exec "$CTRL_PLANE" sed -i \
  's|--listen-metrics-urls=http://127\.0\.0\.1:2381|--listen-metrics-urls=http://0.0.0.0:2381|' \
  /etc/kubernetes/manifests/etcd.yaml

# ─── 4. kube-proxy ──────────────────────────────────────────
echo "[4/4] Patching kube-proxy..."
until kubectl get configmap kube-proxy -n kube-system &>/dev/null; do sleep 2; done
kubectl -n kube-system get configmap kube-proxy -o yaml \
  | sed 's/metricsBindAddress: ""/metricsBindAddress: "0.0.0.0:10249"/' \
  | sed 's/metricsBindAddress: 127\.0\.0\.1:10249/metricsBindAddress: "0.0.0.0:10249"/' \
  | kubectl apply -f - 2>&1 | grep -v "last-applied-configuration" || true
kubectl -n kube-system rollout restart daemonset kube-proxy

# ─── Wait for static pods to restart ────────────────────────
echo "Waiting for control-plane components to restart..."
sleep 8
kubectl -n kube-system wait pod -l component=kube-controller-manager \
  --for=condition=Ready --timeout=90s
kubectl -n kube-system wait pod -l component=kube-scheduler \
  --for=condition=Ready --timeout=90s
kubectl -n kube-system wait pod -l component=etcd \
  --for=condition=Ready --timeout=90s

# ─── Patch VMServiceScrape resources ────────────────────────
echo "Patching VMServiceScrape schemes..."

# etcd → plain HTTP (metrics port 2381 has no TLS)
kubectl patch vmservicescrape \
  "${RELEASE}-victoria-metrics-k8s-stack-kube-etcd" -n "$NS" \
  --type=json -p='[
    {"op":"replace","path":"/spec/endpoints/0/scheme","value":"http"},
    {"op":"remove","path":"/spec/endpoints/0/tlsConfig"},
    {"op":"remove","path":"/spec/endpoints/0/bearerTokenFile"}
  ]' 2>/dev/null || true

# kube-proxy → plain HTTP
kubectl patch vmservicescrape \
  "${RELEASE}-victoria-metrics-k8s-stack-kube-proxy" -n "$NS" \
  --type=json -p='[
    {"op":"replace","path":"/spec/endpoints/0/scheme","value":"http"},
    {"op":"remove","path":"/spec/endpoints/0/tlsConfig"},
    {"op":"remove","path":"/spec/endpoints/0/bearerTokenFile"}
  ]' 2>/dev/null || true

# controller-manager → HTTPS, skip TLS verify, correct port name
kubectl patch vmservicescrape \
  "${RELEASE}-victoria-metrics-k8s-stack-kube-controller-manager" -n "$NS" \
  --type=json -p='[
    {"op":"replace","path":"/spec/endpoints/0/port","value":"http-metrics"},
    {"op":"replace","path":"/spec/endpoints/0/tlsConfig","value":{"insecureSkipVerify":true}}
  ]' 2>/dev/null || true

# scheduler → HTTPS, skip TLS verify, correct port name
kubectl patch vmservicescrape \
  "${RELEASE}-victoria-metrics-k8s-stack-kube-scheduler" -n "$NS" \
  --type=json -p='[
    {"op":"replace","path":"/spec/endpoints/0/port","value":"http-metrics"},
    {"op":"replace","path":"/spec/endpoints/0/tlsConfig","value":{"insecureSkipVerify":true}}
  ]' 2>/dev/null || true

# ─── Fix etcd endpoint port (chart sets 2379, metrics is 2381) ─
echo "Fixing etcd endpoint port (2379 → 2381)..."
kubectl patch endpoints \
  "${RELEASE}-victoria-metrics-k8s-stack-kube-etcd" -n kube-system \
  --type=json \
  -p='[{"op":"replace","path":"/subsets/0/ports/0/port","value":2381}]' \
  2>/dev/null || true

ETCD_SLICE=$(kubectl get endpointslice -n kube-system \
  -l "kubernetes.io/service-name=${RELEASE}-victoria-metrics-k8s-stack-kube-etcd" \
  -o name 2>/dev/null | head -1)
if [ -n "$ETCD_SLICE" ]; then
  kubectl patch -n kube-system "$ETCD_SLICE" \
    --type=json \
    -p='[{"op":"replace","path":"/ports/0/port","value":2381}]' \
    2>/dev/null || true
fi

echo ""
echo "All done! Give VMAgent ~30s to rescrape, then refresh Grafana dashboards."
