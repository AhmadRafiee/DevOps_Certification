# Argocd Total Scenario

## Cluster High Level Design (HLD)
![Argocd HLD](../images/argocd-hld.png)

## Install and config Ingress-nginx, Cert-manager and Argocd on `damavand` cluster

#### Set a Argocd Custom Password: Generate a hashed password
```bash
htpasswd -nbBC 10 "" 'E6ybATayZ0MjWMGf3S5TRmNiH2b' | tr -d ':\n'
```

#### Add the required Helm repositories and update them as needed
```bash
# add helm repository
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add jetstack https://charts.jetstack.io
helm repo add argo https://argoproj.github.io/argo-helm

# Update helm repos
helm repo update ingress-nginx
helm repo update jetstack
helm repo update argo
```

#### deploy Ingress-nginx with helm
```bash
# Change variables file on helm-values/ingress.values.yaml

# deploy ingress-nginx
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
--namespace ingress-nginx \
-f helm-values/ingress.values.yaml \
--create-namespace

# Check resources on ingress nginx namespace
kubectl get all -n ingress-nginx
```

#### deploy Cert-manager with helm
```bash
# Change variables file on helm-values/cert-manager.values.yaml

# deploy cert-manager
helm upgrade --install cert-manager jetstack/cert-manager \
--namespace cert-manager \
-f helm-values/cert-manager.values.yaml \
--create-namespace

# Check resources on cert-manager namespace
kubectl get all -n cert-manager

# Check cluster issuer manifest
cat helm-values/clusterIssuer.yaml

# deploy cluster issuer
kubectl apply -f helm-values/clusterIssuer.yaml

# check clusterIssuer
kubectl get clusterIssuer
```

#### deploy Argocd with helm
```bash
# Change variables file on helm-values/argo.values.yaml

# deploy argocd
helm upgrade --install argo argo/argo-cd --namespace argocd -f helm-values/argo.values.yaml --create-namespace

# check resources on argocd namespace
kubectl get all -n argocd
```

## Install argocd commands | Add other clusters to argocd central

#### Install argocd command-line
```bash
wget https://github.com/argoproj/argo-cd/releases/download/v2.7.5/argocd-linux-amd64
mv argocd-linux-amd64 argocd
chmod +x argocd
sudo mv argocd /usr/bin/local/

# check argocd command
argocd version
```

#### login to main cluster and add other clusters
```bash
# login argocd command to cluster damavand
argocd login argocd.kube.mecan.ir

# after logged in successfully add other clusters
argocd cluster add sahand
argocd cluster add dena

# get list of clusters
argocd cluster list
```

## Add a sample application to the all cluster using a Kubernetes manifest with `argocd` commands.
```bash
# login argocd command to cluster damavand
argocd login argocd.kube.mecan.ir

# add sample app with commands on damavand cluster
argocd app create guestbook-damavand \
--repo https://github.com/AhmadRafiee/DevOps_Certification.git \
--path argocd/guestbook \
--dest-server https://kubernetes.default.svc \
--dest-namespace default

# Sync an app
argocd app sync guestbook-damavand

# add sample app with commands on dena cluster
argocd app create guestbook-dena \
--repo https://github.com/AhmadRafiee/DevOps_Certification.git \
--path argocd/guestbook \
--dest-server https://vip.dena.mecan.ir:6443 \
--dest-namespace default

# Sync an app
argocd app sync guestbook-dena

# add sample app with commands on sahand cluster
argocd app create guestbook-sahand \
--repo https://github.com/AhmadRafiee/DevOps_Certification.git \
--path argocd/guestbook \
--dest-server https://vip.sahand.mecan.ir:6443 \
--dest-namespace default \
--sync-policy auto

# chcek argocd apps
argocd app list

# Delete an app
argocd app delete my-app
```

**Explanation of the Flags:**
  - Creates a new application named `guestbook-dena` in ArgoCD.
  - Uses the repository `DevOps_Certification`.
  - Deploys the manifests from the `argocd/guestbook` path.
  - Targets the Dena cluster at `https://vip.dena.mecan.ir:6443`.
  - Deploys the application into the `default` namespace.
  - Automatically syncs the application with `--sync-policy` auto

## Deploy a sample application to the Damavand cluster using a Helm chart with argocd commands

```bash
# login argocd command to cluster damavand
argocd login argocd.kube.mecan.ir

# add sample app with commands on damavand cluster
argocd app create helm-app-damavand \
--repo https://github.com/AhmadRafiee/DevOps_Certification.git \
--path argocd/helm-guestbook \
--dest-server https://kubernetes.default.svc \
--dest-namespace default \
--helm-set ingress.hosts=test.kube.mecan.ir \
--sync-policy automated

# chcek argocd apps
argocd app list
```

**Explanation of the Flags:**
  - `my-helm-app` → The name of the ArgoCD application.
  - `--repo` → The Git repository containing the Helm chart.
  - `--path` → The path inside the repository where the Helm chart is located.
  - `--dest-server` → The Kubernetes API server address (cluster where the app will be deployed).
  - `--dest-namespace` → The namespace where the app will be deployed.
  - `--helm-set` → Overrides Helm values (optional).
  - `--sync-policy` automated → Automatically syncs the application.

## Add a sample application to the damavand cluster using a helm chart with `argocd` commands

```bash
# login argocd command to cluster damavand
argocd login argocd.kube.mecan.ir

# add sample app with commands on damavand cluster
argocd app create kustomize-app-damavand \
--repo https://github.com/AhmadRafiee/DevOps_Certification.git \
--path argocd/kustomize-guestbook \
--dest-server https://kubernetes.default.svc \
--dest-namespace default \
--sync-policy automated

# chcek argocd apps
argocd app list
```

**Explanation of the Flags:**
  - `my-kustomize-app` → Name of the ArgoCD application.
  - `--repo` → The Git repository containing the Kustomize manifests.
  - `--path` → The path inside the repo where kustomization.yaml is located.
  - `--dest-server` → The Kubernetes API server address (destination cluster).
  - `--dest-namespace` → The namespace where the app will be deployed.
  - `--sync-policy` automated → Enables automatic synchronization.

## Add a sample application to the damavand cluster using a helm chart with `argocd` commands

![app-of-apps](../images/app-of-apps.png)

before setup app-of-apps change varibles file:
```bash
cat argocd/app-of-apps-gustbook/values.yaml
spec:
  destination:
    server: https://kubernetes.default.svc
  source:
    repoURL: https://github.com/AhmadRafiee/DevOps_Certification
    targetRevision: HEAD
```

after change varible file setup app-of-apps on argocd
```bash
# login argocd command to cluster damavand
argocd login argocd.kube.mecan.ir

# create app of apps from DevOps Certification repo
argocd app create app-of-apps-gustbook \
--dest-namespace argocd \
--dest-server https://kubernetes.default.svc \
--repo https://github.com/AhmadRafiee/DevOps_Certification.git \
--path argocd/app-of-apps-gustbook \
--sync-policy auto

# Check argocd app list
argocd app list

# sync app-of-apps-gustbook
argocd app sync app-of-apps-gustbook
```

[Good Link](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/#app-of-apps-pattern) and [Good Repo](https://github.com/argoproj/argocd-example-apps/tree/master/apps)

## Add a sample application to the `damavand` cluster using a helm chart with `argocd` commands

![k8s-addons-app](../images/k8s-addons-app.png)

before setup app-of-apps change varibles file:
```bash
cat argocd/k8s-addons-app/values.yaml
spec:
  destination:
    server: https://kubernetes.default.svc
  minio:
    repoURL: https://charts.min.io/
    targetRevision: "5.4.0"
    chart: minio
    releaseName: minio
    valueFiles: https://raw.githubusercontent.com/AhmadRafiee/DevOps_Certification/refs/heads/main/kubernetes/add-ons/minio/helm.values.yaml
    namespace: minio
  velero:
    repoURL: https://vmware-tanzu.github.io/helm-charts/
    targetRevision: "8.3.0"
    chart: velero
    releaseName: velero
    valueFiles: https://raw.githubusercontent.com/AhmadRafiee/DevOps_Certification/refs/heads/main/kubernetes/add-ons/velero/helm.values.yaml
    namespace: velero
  loki:
    repoURL: https://grafana.github.io/helm-charts
    targetRevision: "2.10.2"
    chart: loki-stack
    releaseName: loki
    valueFiles: https://raw.githubusercontent.com/AhmadRafiee/DevOps_Certification/refs/heads/main/kubernetes/add-ons/loki-stack/helm.values.yaml
    namespace: loki-stack
  prometheus:
    repoURL: https://prometheus-community.github.io/helm-charts
    targetRevision: "69.3.1"
    chart: kube-prometheus-stack
    releaseName: prometheus-stack
    valueFiles: https://raw.githubusercontent.com/AhmadRafiee/DevOps_Certification/refs/heads/main/kubernetes/add-ons/kube-prometheus-stack/helm.values.yaml
    namespace: monitoring
```

after change varible file setup app-of-apps on argocd
```bash
# login argocd command to cluster damavand
argocd login argocd.kube.mecan.ir

# create app of apps from DevOps Certification repo
argocd app create k8s-addons-app \
--dest-namespace argocd \
--dest-server https://kubernetes.default.svc \
--repo https://github.com/AhmadRafiee/DevOps_Certification.git \
--path argocd/k8s-addons-app \
--sync-policy auto

# Check argocd app list
argocd app list

# sync k8s-addons-app
argocd app sync k8s-addons-app
```

## Here’s how you can create an ApplicationSet in ArgoCD to deploy MinIO, Ingress, and multiple applications using a Helm chart across two specific clusters (Sahand & Dena).

#### deploy Minio with ApplicationSet across two specific clusters (Sahand & Dena).

```bash
# minio applicationset path
cat argocd/applicationset/minio/minio-appset.yaml

# login argocd command to cluster damavand
argocd login argocd.kube.mecan.ir

# create app of apps from DevOps Certification repo
argocd app create minio-appset \
--dest-namespace argocd \
--dest-server https://kubernetes.default.svc \
--repo https://github.com/AhmadRafiee/DevOps_Certification.git \
--path argocd/applicationset/minio \
--sync-policy auto

# Check argocd app list
argocd app list

# sync minio-appset
argocd app sync minio-appset
```

#### deploy Ingress Nginx with ApplicationSet across two specific clusters (Sahand & Dena).

```bash
# ingress applicationset path
cat argocd/applicationset/ingress/ingress-appset.yaml

# login argocd command to cluster damavand
argocd login argocd.kube.mecan.ir

# create app of apps from DevOps Certification repo
argocd app create ingress-appset \
--dest-namespace argocd \
--dest-server https://kubernetes.default.svc \
--repo https://github.com/AhmadRafiee/DevOps_Certification.git \
--path argocd/applicationset/ingress \
--sync-policy auto

# Check argocd app list
argocd app list

# sync ingress-appset
argocd app sync ingress-appset
```

#### Deploy multiple apps with ApplicationSet across two specific clusters (Sahand & Dena).

![multiple-app-appset](../images/multiple-app-applicationset.png)

**file and directory structure**
```bash
├── multiple-apps.yaml
└── values
    ├── dena
    │   ├── ingress-nginx-values.yaml
    │   ├── minio-values.yaml
    │   └── velero-values.yaml
    └── sahand
        ├── ingress-nginx-values.yaml
        ├── minio-values.yaml
        └── velero-values.yaml
```

**login to central argocd and deploy multiple apps with ApplicationSet**

```bash
# multiple-app applicationset path
cat argocd/applicationset/multiple-apps/multiple-apps.yaml

# login argocd command to cluster damavand
argocd login argocd.kube.mecan.ir

# create app of apps from DevOps Certification repo

argocd app create k8s-addons-appset \
--dest-namespace argocd \
--dest-server https://kubernetes.default.svc \
--repo https://github.com/AhmadRafiee/DevOps_Certification.git \
--path argocd/applicationset/multiple-apps \
--sync-policy auto

# Check argocd app list
argocd app list

# sync k8s-addons-appset
argocd app sync k8s-addons-appset
```

## Add a voting application to the damavand cluster using a helm chart with `argocd` commands.
```bash
# login argocd command to cluster damavand
argocd login argocd.kube.mecan.ir

# add sample app with commands on damavand cluster
argocd app create voting-app \
--repo https://github.com/AhmadRafiee/DevOps_Certification.git \
--path argocd/voting-app \
--dest-server https://kubernetes.default.svc \
--helm-set ingress.hosts=test.kube.mecan.ir \
--sync-policy automated

# chcek argocd apps
argocd app list
```


## Useful commands

```bash
# delete app with commands
argocd app delete voting-app

# patch finalizers if exist
kubectl -n argocd patch app k8s-addons-app --type merge -p '{"metadata": {"finalizers": null}}'
```

## Good Link
  - [applicationset](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/)
  - [multiple_sources](https://argo-cd.readthedocs.io/en/stable/user-guide/multiple_sources/)
  - [Generating Applications with ApplicationSet](https://argo-cd.readthedocs.io/en/stable/user-guide/application-set/)
  - [app of app and appset](https://codefresh.io/blog/how-to-structure-your-argo-cd-repositories-using-application-sets/)
  - [many-appsets-demo](https://github.com/kostis-codefresh/many-appsets-demo)