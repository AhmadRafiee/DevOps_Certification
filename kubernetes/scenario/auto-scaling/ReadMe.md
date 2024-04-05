# Auto Scaling

In Kubernetes, you can scale a workload depending on the current demand of resources. This allows your cluster to react to changes in resource demand more elastically and efficiently.

When you scale a workload, you can either increase or decrease the number of replicas managed by the workload, or adjust the resources available to the replicas in-place.

The first approach is referred to as horizontal scaling, while the second is referred to as vertical scaling.

There are manual and automatic ways to scale your workloads, depending on your use case.

Three common solutions for scaling applications in Kubernetes environments are:

- **Horizontal Pod Autoscaler (HPA):** Automatically adds or removes pod replicas.
- **Vertical Pod Autoscaler (VPA):** Automatically adds or adjusts CPU and memory reservations for your pods.
- **Cluster Autoscaler:** Automatically adds or removes nodes in a cluster based on all pods’ requested resources.

### Auto Scaling Requirements:

**Metric Server**
Metrics Server collects resource metrics from Kubelets and exposes them in Kubernetes apiserver through Metrics API for use by Horizontal Pod Autoscaler and Vertical Pod Autoscaler. Metrics API can also be accessed by `kubectl top` , making it easier to debug autoscaling pipelines.

Metrics Server is not meant for non-autoscaling purposes. For example, don’t use it to forward metrics to monitoring solutions, or as a source of monitoring solution metrics. In such cases please collect metrics from Kubelet `/metrics/resource` endpoint directly.


**Metrics Server offers:**

- A single deployment that works on most clusters
- Fast autoscaling, collecting metrics every 15 seconds.
- Resource efficiency, using 1 mili core of CPU and 2 MB of memory for each node in a cluster.
- Scalable support up to 5,000 node clusters.

Create metric server

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

Check metric server

```bash
kubectl get all -n kube-system | grep metrics-server
```

Metric server test

```bash
kubectl top pod
kubectl top node
```

Fix metric server issue

```bash
# add these configuration on deployment manifest metric server
kubectl edit deployment metrics-server
        - --kubelet-insecure-tls
        - --authorization-always-allow-paths=/livez,/readyz
```

### VPA Install command

To install VPA, please download the source code of VPA (for example with git clone https://github.com/kubernetes/autoscaler.git) and run the following command inside the `vertical-pod-autoscaler` directory:

```bash
./hack/vpa-up.sh
```

### Auto Scaling test

**Step 1:** deploy `php-apache` deployment and service

```
kubectl apply -f php-app/01.php-app.yml
```

check `php-apache` deployment

```
kubectl get deployment,pod
kubectl top pod
```

create `php-apache` service

```bash
kubectl apply -f php-app/02.php-service.yml
```

**Step 2:** create HPA and VPA resource for `php-apache` deployment

```bash
kubectl apply -f php-app/04.php-hpa.yml
kubectl apply -f php-app/05.php-vpa.yml
```

check hpa and vpa resource

```bash
kubectl get hpa,vpa
```

**Step 3:** after create and check all resource create load with `load-generator` deployment

```bash
kubectl apply -f php-app/03.load-generator.yml
```

**Happy Scaling**