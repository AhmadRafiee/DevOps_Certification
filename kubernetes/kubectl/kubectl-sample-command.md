# Kubectl Sample Commands

 The Kubernetes command-line tool, kubectl, allows you to run commands against Kubernetes clusters. You can use kubectl to deploy applications, inspect and manage cluster resources, and view logs. For more information including a complete list of kubectl operations, see the kubectl reference documentation.

#
#### [Overview of kubectl](https://kubernetes.io/docs/reference/kubectl/overview/)

The kubectl command line tool lets you control Kubernetes clusters. For configuration, kubectl looks for a file named config in the $HOME/.kube directory. You can specify other kubeconfig files by setting the KUBECONFIG environment variable or by setting the --kubeconfig flag.

This overview covers kubectl syntax, describes the command operations, and provides common examples. For details about each command, including all the supported flags and subcommands, see the kubectl reference documentation. For installation instructions see installing kubectl.

#
#### Syntax
Use the following syntax to run kubectl commands from your terminal window:
```
kubectl [command] [TYPE] [NAME] [flags]
```

- **command:** Specifies the operation that you want to perform on one or more resources, for example create, get, describe, delete.

- **TYPE:** Specifies the resource type. Resource types are case-insensitive and you can specify the singular, plural, or abbreviated forms. For example, the following commands produce the same output:

- **NAME:** Specifies the name of the resource. Names are case-sensitive. If the name is omitted, details for all resources are displayed, for example kubectl get pods.

- **flags:** Specifies optional flags. For example, you can use the -s or --server flags to specify the address and port of the Kubernetes API server.

#
#### kubectl config

```bash
kubectl config current-context
kubectl config view
kubectl config set-context dev --namespace=development \
  --cluster=lithe-cocoa-92103_kubernetes \
  --user=lithe-cocoa-92103_kubernetes
kubectl config use-context dev
kubectl config view --kubeconfig my-kube-config
kubectl config --kubeconfig=/root/my-kube-config use-context research
```

#
#### expose api on 8001 port
```bash
kubectl proxy
```

#
#### get all object

```bash
kubectl get all --all-namespaces
```

#
#### node commands

```bash
kubectl get node
kubectl edit node msater
kubectl get nodes --show-labels
kubectl drain <node name>
kubectl uncordon <node name>
kubectl drain node01 --ignore-daemonsets
kubectl describe node master
kubectl cordon node03
```

#
#### taints

```bash
kubectl taint nodes <node-name> key=value:taint-effect
kubectl taint nodes node1 app=blue:NoSchedule
```

#
#### logs

```bash
kubectl logs -f event-simulator-pod
kubectl logs -f <pod-name> <container-name>
kubectl logs -f even-simulator-pod event-simulator
```

#
#### pod

```bash
kubectl get pods -n kube-system
kubectl get pods -o wide
kubectl get pods -l app=snowflake -n=development
kubectl run nginx --image=nginx --namespace=<insert-namespace-name-here>
kubectl get pods --namespace=<insert-namespace-name-here>
kubectl get pods --selector env=dev
kubectl get all --selector env=prod,bu=finance,tier=frontend
kubectl logs my-custom-scheduler -n kube-system
```

#
#### service

```bash
kubectl get services
kubectl describe service
```

#
#### namespace

```bash
kubectl create ns test
kubectl create namespace dev
kubectl get pods --namespace=test
kubectl run redis --image=redis --namespace=test
kubectl get pods --all-namespaces
kubectl create -f pod-definition.yaml --namespace=dev
kubectl get namespaces
```

#
#### run pod without manifest

```bash
kubectl run httpd --image=httpd:alpine --port=80 --expose
kubectl run nginx-pod --image=nginx:alpine
kubectl run redis --image=redis:alpine -l tier=db
kubectl run custom-nginx --image=nginx --port=8080
kubectl run httpd --image=httpd:alpine --port=80 --expose
kubectl get pods --selector app=App1
```

#
#### expose

```bash
kubectl expose pod redis --port=6379 --name redis-service
```

#
#### secret

```bash
kubectl get secrets
kubectl describe secret
kubectl create secret generic db-secret --from-literal=DB_Host=sql01 --from-literal=DB_User=root --from-literal=DB_Password=password123
```

#
#### deployment

```bash
kubectl create deployment webapp --image=kodekloud/webapp-color
kubectl get deployment
kubectl get replicaset
kubectl get rs
kubectl describe deployment
kubectl create deployment httpd-frontend --image=httpd:2.4-alpine
kubectl scale deplyoment httpd-frontend --replicas=3
kubectl edit deployment.v1.apps/nginx-deployment
kubectl rollout status deployment/nginx-deployment
kubectl rollout undo deployment.v1.apps/nginx-deployment
kubectl scale deployment.v1.apps/nginx-deployment --replicas=10
kubectl set image deployment.v1.apps/nginx-deployment nginx=nginx:sometag
kubectl scale deployment blue --replicas=6
kubectl scale deployment.v1.apps/nginx-deployment --replicas=10
kubectl autoscale deployment.v1.apps/nginx-deployment --min=10 --max=15 --cpu-percent=80
```

#
#### rollout

```bash
kubectl rollout status deployment/myapp-deployment
kubectl rollout history deployment/myapp-deployment
kubectl rollout undo deployment/myapp-deployment
```

#
#### Network Policies

```bash
kubectl get networkpolicy
kubectl describe networkpolicy
```

#
#### daemonsets

```bash
kubectl get daemonsets --all-namespaces
kubectl describe daemonset kube-proxy --namespace=kube-system
kubectl describe daemonset kube-flannel-ds-amd64 --namespace=kube-system
```

#
#### label

```bash
kubectl label node ubuntu owner=alpin         # add label
kubectl label node ubuntu owner-              # remove label
```

#
#### scale

```bash
kubectl scale deployment/webapp --replicas=3
# You can also use kubectl scale deployment or kubectl edit deployment to change the number of replicas once the object has been created.
kubectl edit deployment redis-deploy
kubectl scale deployment/redis-deploy --replicas=2 --namespace=dev-ns
```

#
#### ConfigMaps

```bash
kubectl create configmap app-config --from-literal=APP_COLOR=blue --from-literal=APP_MODE=prod
kubectl create configmap app-config --from-file=app_config.properties (Another way)
```

#
#### set

```bash
kubectl set image deployment/myapp-deployment nginx=nginx:1.9.1
```

#
#### Cluster Roles

```bash
kubectl get clusterroles --no-headers | wc -l (or)
kubectl get clusterroles --no-headers -o json | jq '.items | length'
kubectl get clusterrolebindings --no-headers | wc -l (or)
kubectl get clusterrolebindings --no-headers -o json | jq '.items | length'
kubectl describe clusterrolebinding cluster-admin
```

#
#### check access

```bash
kubectl auth can-i create deployments
kubectl auth can-i delete nodes
kubectl auth can-i create deployments --as dev-user
kubectl auth can-i create pods --as dev-user
kubectl auth can-i create pods --as dev-user --namespace test
```

#
#### RBAC

```bash
kubectl get roles
kubectl get rolebindings
kubectl describe role developer
kubectl describe rolebinding devuser-developer-binding
```

#
#### create sample yaml file

```bash
kubectl run --restart=Never --image=busybox static-busybox --dry-run=client -o yaml --command -- sleep 1000 > /etc/kubernetes/manifests/static-busybox.yaml
```

#
#### create yaml file with scenario

```bash
# Step 1: Create the deployment YAML file
kubectl create deployment redis-deploy --image redis --namespace=dev-ns --dry-run=client -o yaml > deploy.yaml
kubectl create -f deploy.yaml

# Step 2: Edit the YAML file and add update the replicas to 2.

#Step 3: Run kubectl apply -f deploy.yaml to create the deployment in the dev-ns namespace.
kubectl apply -f deploy.yaml
```

#
#### check certificate commands

```bash
openssl x509 -in /etc/kubernetes/pki/ca.crt -text
openssl x509 -in /etc/kubernetes/pki/apiserver.crt -text
openssl x509 -in /etc/kubernetes/pki/etcd/server.crt -text
```

#
#### Create new labels

```bash
# You can create own labels
kubectl label nodes <node-name> <label-key>=<label-value>

# Example
kubectl label nodes minikube foo=bar
```

#
#### json pacth

```bash
kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}' > /root/CKA/node_ips
kubectl get nodes -o=jsonpath='{.items[*].metadata.name}'
kubectl get nodes -o jsonpath='{.items[*].status.nodeInfo.osImage}'
```

#
#### Good Commands:

```bash
kubectl drain <NODE_NAME> --ignore-daemonsets --delete-local-data
```