# Kubernetes-based Event Driven Autoscaler (KEDA) Scenario

- [Kubernetes-based Event Driven Autoscaler (KEDA) Scenario](#kubernetes-based-event-driven-autoscaler-keda-scenario)
  - [⚙️ Requirements](#️-requirements)
  - [🛠 Install KEDA](#-install-keda)
  - [🚀 Deploy voting app service and deployment](#-deploy-voting-app-service-and-deployment)
  - [📄 Create KEDA ScaledObject for Redis](#-create-keda-scaledobject-for-redis)
  - [🧪 Test the Scaling](#-test-the-scaling)
  - [📊 check manual Redis queue](#-check-manual-redis-queue)
  - [Install KEDA HTTP Add-on](#install-keda-http-add-on)
  - [Deploy Sample HTTP App](#deploy-sample-http-app)
  - [Port Forward the KEDA Interceptor (for testing)](#port-forward-the-keda-interceptor-for-testing)
  - [Test HTTP Scaling](#test-http-scaling)
  - [🐇 RabbitMQ Autoscaling Scenario with KEDA](#-rabbitmq-autoscaling-scenario-with-keda)



## ⚙️ Requirements

- A Kubernetes cluster (minikube, kind, k3s, etc.)
- `kubectl` installed and configured
- Internet access for pulling container images

---

## 🛠 Install KEDA

```bash
kubectl create namespace keda
kubectl apply -f https://github.com/kedacore/keda/releases/download/v2.17.1/keda-2.17.1.yaml

# OR
kubectl replace --force -f https://github.com/kedacore/keda/releases/download/v2.17.1/keda-2.17.1.yaml
```

Wait until all KEDA pods are running:

```bash
kubectl get pods -n keda
```
---
## 🚀 Deploy voting app service and deployment

deploy all manifest voting app from this [path](https://github.com/AhmadRafiee/DevOps_Certification/tree/main/kubernetes/scenario/voting-app)

## 📄 Create KEDA ScaledObject for Redis

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: worker-scaledobject
spec:
  scaleTargetRef:
    name: worker
  pollingInterval: 2            # Check every 2 seconds
  cooldownPeriod: 5             # Wait 5s before scaling down
  minReplicaCount: 0            # Min Replication
  maxReplicaCount: 5            # Max Replication
  triggers:
    - type: redis
      metadata:
        address: redis:6379
        listName: votes
        listLength: "1"        # Scale up when there are at least 1 items in the list
```

apply this scaledobject
```bash
kubectl apply -f redis-scaleobject.yml
```
## 🧪 Test the Scaling

You can simulate vote traffic (push items to the Redis list):

```bash
# port forward vote serivce
kubectl port-forward svc/vote 8080:8080

# run these command for vote a and b
ab -n 1000 -c 50 -p posta -T "application/x-www-form-urlencoded" http://127.0.0.1:8080/
ab -n 1000 -c 50 -p postb -T "application/x-www-form-urlencoded" http://127.0.0.1:8080/
```

Then watch the worker pods scale:

```bash
kubectl get pods -l app=worker -w
```

## 📊 check manual Redis queue

check it votes queue counts

```bash
kubectl run redis-cli --image=redis:7.2 -it --rm -- bash

# Inside container:
redis-cli -h redis
LLEN votes
```

## Install KEDA HTTP Add-on

```bash
helm repo add kedacore https://kedacore.github.io/charts
helm repo update kedacore

helm install keda-add-ons-http kedacore/keda-add-ons-http \
  --namespace keda \
  --set service.type=ClusterIP
```

## Deploy Sample HTTP App

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-app
spec:
  selector:
    app: my-app
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 0
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
        - name: app
          image: hashicorp/http-echo
          args:
            - "-text=Hello from app"
            - "-listen=:8080"
          ports:
            - containerPort: 8080
```

Apply:

```bash
kubectl apply -f app.yaml
```

4. Deploy HTTPScaledObject

```yaml
apiVersion: http.keda.sh/v1alpha1
kind: HTTPScaledObject
metadata:
  name: my-app-http
spec:
  hosts:
    - my-app.local
  targetPendingRequests: 5
  scaleTargetRef:
    deployment: my-app
    service: my-app
    port: 80
  replicas:
    min: 0
    max: 5
```
Apply:

```bash
kubectl apply -f http-scaledobject.yaml
```

## Port Forward the KEDA Interceptor (for testing)
```bash
kubectl port-forward svc/keda-add-ons-http-interceptor-proxy 8080:8080 -n keda
```
This exposes the KEDA HTTP proxy at localhost:8080.

## Test HTTP Scaling
In another terminal, run:

```bash
while true; do curl -H "Host: my-app.local" http://localhost:8080/; sleep 0.1; done
```
And in another terminal, watch the pod scaling:

```bash
watch kubectl get pods -l app=my-app
```

## 🐇 RabbitMQ Autoscaling Scenario with KEDA
This repository contains Kubernetes manifests to deploy a RabbitMQ-based autoscaling scenario using KEDA (Kubernetes Event-driven Autoscaling). It demonstrates how to create a RabbitMQ queue, deploy producers and consumers, and autoscale consumer pods based on the queue length.

File Structure
```bash
rabbitmq-scenario
├── 01.rabbitmq-sample.yml       # RabbitMQ deployment and basic setup
├── 02.rabbitmq-service.yml      # RabbitMQ Service definition
├── 03.secret.yml                # Secrets for RabbitMQ credentials
├── 04.consumer.yml              # Consumer Deployment to process messages
├── 05.scaledobject.yml          # KEDA ScaledObject to autoscale consumer pods
├── 06.trigger.yml               # KEDA Trigger Authentication configuration
├── 07.create-queue.yml          # Job to create RabbitMQ queue and send test messages
```

Setup Instructions
**Deploy RabbitMQ**

Apply RabbitMQ deployment and service manifests:

```bash
kubectl apply -f 01.rabbitmq-sample.yml
kubectl apply -f 02.rabbitmq-service.yml
```

**Create Secrets**

Create the required secrets for RabbitMQ authentication:

```bash
kubectl apply -f 03.secret.yml
```

Create RabbitMQ Queue and Send Test Messages

Run the job that creates the test-queue and publishes sample messages:

```bash
kubectl apply -f 07.create-queue.yml
```

**Deploy Consumer**
Deploy the consumer pods which will read messages from the queue:

```bash
kubectl apply -f 04.consumer.yml
```

**Configure KEDA Authentication**

Setup KEDA trigger authentication for RabbitMQ:

```bash
kubectl apply -f 06.trigger.yml
```

**Apply ScaledObject**

Create the KEDA ScaledObject to enable autoscaling of consumers based on queue length:

```bash
kubectl apply -f 05.scaledobject.yml
```

**How It Works**
  - The Job in 07.create-queue.yml creates a durable queue named test-queue and sends 50 test messages to it.
  - The Consumer deployment (04.consumer.yml) reads messages from test-queue.
  - KEDA monitors the length of test-queue using the ScaledObject (05.scaledobject.yml) and automatically scales the consumer deployment up or down.
  - Authentication for the trigger is handled securely via 06.trigger.yml referencing the secret created in 03.secret.yml.

**Notes**
  - Make sure RabbitMQ is accessible from the consumer pods.
  - Adjust the minReplicaCount and maxReplicaCount in the ScaledObject to suit your workload.
  - You can monitor the scaling by checking the number of consumer pods:
```bash
kubectl get pods -l app=consumer
```
  - Logs for consumer pods will show the message processing.