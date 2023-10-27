# kind
![kind](../../../images/kind.png "Kind")

kind is a tool for running local Kubernetes clusters using Docker container “nodes”.
kind was primarily designed for testing Kubernetes itself, but may be used for local development or CI.

#### Installation:
To install, download the binary for your platform from “Assets”, then rename it to kind (or perhaps kind.exe on Windows) and place this into your $PATH at your preferred binary installation directory.

```bash
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.11.1/kind-linux-amd64
chmod +x ./kind
mv ./kind /usr/local/bin/kind
```

#### kind bash completion

```
sudo kind completion bash > /etc/bash_completion.d/kind
sudo kind completion zsh > /etc/bash_completion.d/kind
```

#### Configuration file
To configure kind cluster creation, you will need to create a YAML config file. This file follows Kubernetes conventions for versioning etc.


#### Multi-node clusters with Kind

In particular, many users may be interested in multi-node clusters. A simple configuration for this can be achieved with the following config file contents:

```
# three node (two workers) cluster config
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
- role: worker
```

#### Control-plane HA

You can also have a cluster with multiple control-plane nodes:

```bash
# a cluster with 3 control-plane nodes and 3 workers
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: control-plane
- role: control-plane
- role: worker
- role: worker
- role: worker
```

```bash
kind create cluster --name my-cluster
```

[Configuration sample doc.](https://kind.sigs.k8s.io/docs/user/configuration/)

#### Creating a Cluster

Creating a Kubernetes cluster is as simple as `kind create cluster.`

```bash
kind create cluster
kind create cluster --image kindest/node:latest
```

#### Deleting a Cluster
If you created a cluster with kind create cluster then deleting is equally simple:

```bash
kind delete cluster
```

If the flag --name is not specified, kind will use the default cluster context name kind and delete that cluster.


#### Loading an Image Into Your Cluster
Docker images can be loaded into your cluster nodes with:

```
kind load docker-image my-custom-image-0 my-custom-image-1
```

#### kind kubernetes sample config:

- [Single node with ingress config](single-node-with-ingress.yml)
- [Single node with port binding](single-node-with-port-binding.yml)
- [Multi nodes](multi-node.yml)
- [Multi nodes with custom version](multi-node-custom-version.yml)
- [Multi nodes with port binding](multi-node-with-port-binding.yml)
- [Multi nodes with custom version and port binding](multi-node-custom-version-port-binding.yml)
- [Multi node with multi masters](multi-node-multi-masters.yml)