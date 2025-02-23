# Rancher Kubernetes Engine (RKE)
RKE is a CNCF-certified Kubernetes distribution that runs entirely within Docker containers. It solves the common frustration of installation complexity with Kubernetes by removing most host dependencies and presenting a stable path for deployment, upgrades, and rollbacks.


#### Install rke commands:
```bash
wget https://github.com/rancher/rke/releases/download/v1.5.7/rke_linux-amd64
chmod +x rke_linux-amd64
mv rke_linux-amd64 rke
sudo mv rke /usr/local/bin
```

#### Collect and Publish Images to your Private Registry with these scripts:
Get scripts for download, save and load images to registry:
```bash
# rancher container images list:
wget https://github.com/rancher/rancher/releases/download/v2.8.3/rancher-images.txt

# download and save images to file:
wget https://github.com/rancher/rancher/releases/download/v2.8.3/rancher-save-images.sh

# load image from file:
wget https://github.com/rancher/rancher/releases/download/v2.8.3/rancher-load-images.sh
```

#### Get all kubernetes version support image list
```bash
# list all kubernetes version support
rke config --list-version

# list all image for all version
rke config --list-version --all --system-images
```

#### Save the images to your workstation
Make `rancher-save-images.sh` an executable:
```bash
chmod +x rancher-save-images.sh
```
Run `rancher-save-images.sh` with the `rancher-images.txt` image list to create a tarball of all the required images:
```bash
./rancher-save-images.sh --image-list ./rancher-images.txt
```
**Result:** Docker begins pulling the images used for an air gap install. Be patient. This process takes a few minutes. When the process completes, your current directory will output a tarball named `rancher-images.tar.gz`. Check that the output is in the directory.

In the other way get all image for all version
```bash
# get and save image list
rke config --list-version --all --system-images > rancher-images.txt
# download all images
./rancher-save-images.sh --image-list ./rancher-images.txt
```

### Populate the private registry
Next, you will move the images in the `rancher-images.tar.gz` to your private registry using the scripts to load the images.

Move the images in the `rancher-images.tar.gz` to your private registry using the scripts to load the images.

The `rancher-images.txt` is expected to be on the workstation in the same directory that you are running the rancher-load-images.sh script. The `rancher-images.tar.gz` should also be in the same directory.


Log into your private registry if required:
```bash
docker login https://registry.mecan.ir
```
Make rancher-load-images.sh an executable:
```bash
chmod +x rancher-load-images.sh
```
Use rancher-load-images.sh to extract, tag and push rancher-images.txt and rancher-images.tar.gz to your private registry:
```bash
./rancher-load-images.sh --image-list ./rancher-images.txt --registry registry.mecan.ir
```

#### install requarments rke on all kubernetes nodes
```bash
# install docker and post install on all nodes
which docker || { curl -fsSL https://get.docker.com | bash; }
sudo usermod -aG docker $USER
```

#### Create `cluster.yml` file
```bash
cat <<EOF >> cluster.yml
nodes:
  - address: 192.168.56.101
    port: 22
    role: ['controlplane', 'etcd', 'worker']
    hostname_override: "master1"
    user: vagrant
  - address: 192.168.56.102
    port: 22
    role: ['controlplane', 'etcd', 'worker']
    hostname_override: "master2"
    user: vagrant
  - address: 192.168.56.103
    port: 22
    role: ['controlplane', 'etcd', 'worker']
    hostname_override: "master3"
    user: vagrant

services:
  kube-api:
    audit_log:
      enabled: true
      configuration:
        max_age: 6
        max_backup: 6
        max_size: 110
        path: /var/log/kube-audit/audit-log.json
        format: json
        policy:
          apiVersion: audit.k8s.io/v1 # This is required.
          kind: Policy
          omitStages:
            - "RequestReceived"
          rules:
            - level: RequestResponse
              resources:
              - group: ""
                resources: ["pods"]
    service_cluster_ip_range: 10.43.0.0/16
    service_node_port_range: 30000-32767
  kube-controller:
    cluster_cidr: 10.42.0.0/16

  kubelet:
    cluster_domain: cluster.local
    extra_args:
      max-pods: 250
      feature-gates: RotateKubeletServerCertificate=true

network:
  plugin: calico

authentication:
  strategy: x509
  sans:
    - "192.168.56.100"
    - "192.168.56.101"
    - "192.168.56.102"
    - "192.168.56.103"
    - "master.kube.mecan.ir"
    - "master1.kube.mecan.ir"
    - "master2.kube.mecan.ir"
    - "master3.kube.mecan.ir"

authorization:
  mode: rbac

ignore_docker_version: true
kubernetes_version: "v1.25.5-rancher1-1"
cluster_name: "MeCan"

private_registries:
  - url: registry.mecan.ir
    user: MeCan
    password: PASS
    is_default: true
EOF
```

#### Run RKE
After configuring cluster.yml, bring up your Kubernetes cluster:
```bash
rke up --config ./cluster.yml
```

#### Save Your Files
Important The files mentioned below are needed to maintain, troubleshoot and upgrade your cluster.

Save a copy of the following files in a secure location:

`cluster.yml`: The RKE cluster configuration file.
`kube_config_rancher-cluster.yml`: The Kubeconfig file for the cluster, this file contains credentials for full access to the cluster.
`rancher-cluster.rkestate`: The Kubernetes Cluster State file, this file contains the current state of the cluster including the RKE configuration and the certificates.

The Kubernetes Cluster State file is only created when using RKE v0.2.0 or higher.
