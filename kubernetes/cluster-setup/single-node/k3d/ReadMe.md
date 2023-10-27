# K3D

#### What is k3d?
k3d is a lightweight wrapper to run k3s (Rancher Lab’s minimal Kubernetes distribution) in docker.
k3d makes it very easy to create single- and multi-node k3s clusters in docker, e.g. for local development on Kubernetes.
**Note:** k3d is a community-driven project but it’s not an official Rancher (SUSE) product. Sponsoring: To spend any significant amount of time improving k3d, we rely on sponsorships:

#
#### Requirements
**docker** to be able to use k3d at all
**Note**: k3d v5.x.x requires at least Docker v20.10.5 (runc >= v1.0.0-rc93) to work properly (see #807)
**kubectl** to interact with the Kubernetes cluster

#
#### Installation
Install current latest release
```bash
# with wget
wget -q -O - https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
# with curl
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
```

Install specific release
Use the install script to grab a specific release (via TAG environment variable):
```bash
# with wget:
wget -q -O - https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | TAG=v5.0.0 bash
# with curl:
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | TAG=v5.0.0 bash
```

#
#### k3d completion
To load completions for Bash:

```bash
source <(k3d completion bash)

# To load completions for each session, execute once:
# Linux:
k3d completion bash > /etc/bash_completion.d/k3d
```

#
#### Quick Start

Create a cluster named mycluster with just a single server node:

```bash
k3d cluster create mycluster
```

Use the new cluster with kubectl, e.g.:

```bash
kubectl get nodes
```

#
#### Using Config Files
Using a config file is as easy as putting it in a well-known place in your file system and then referencing it via flag:
- All options in config file: `k3d cluster create --config /home/me/my-awesome-config.yaml` (must be .yaml/.yml)
- With CLI override (name): `k3d cluster create somename --config /home/me/my-awesome-config.yaml`
- With CLI override (extra volume): `k3d cluster create --config /home/me/my-awesome-config.yaml --volume '/some/path:/some:path@server:0'`

#
#### Config Options
The configuration options for k3d are continuously evolving and so is the config file (syntax) itself.
Currently, the config file is still in an Alpha-State, meaning, that it is subject to change anytime (though we try to keep breaking changes low).

All Options: Example
Since the config options and the config file are changing quite a bit, it’s hard to keep track of all the supported config file settings, so here’s an example showing all of them as of the time of writing:

```bash
# k3d configuration file, saved as e.g. /home/me/myk3dcluster.yaml
apiVersion: k3d.io/v1alpha5 # this will change in the future as we make everything more stable
kind: Simple # internally, we also have a Cluster config, which is not yet available externally
metadata:
  name: mycluster # name that you want to give to your cluster (will still be prefixed with `k3d-`)
servers: 1 # same as `--servers 1`
agents: 2 # same as `--agents 2`
kubeAPI: # same as `--api-port myhost.my.domain:6445` (where the name would resolve to 127.0.0.1)
  host: "myhost.my.domain" # important for the `server` setting in the kubeconfig
  hostIP: "127.0.0.1" # where the Kubernetes API will be listening on
  hostPort: "6445" # where the Kubernetes API listening port will be mapped to on your host system
image: rancher/k3s:v1.20.4-k3s1 # same as `--image rancher/k3s:v1.20.4-k3s1`
network: my-custom-net # same as `--network my-custom-net`
subnet: "172.28.0.0/16" # same as `--subnet 172.28.0.0/16`
token: superSecretToken # same as `--token superSecretToken`
volumes: # repeatable flags are represented as YAML lists
  - volume: /my/host/path:/path/in/node # same as `--volume '/my/host/path:/path/in/node@server:0;agent:*'`
    nodeFilters:
      - server:0
      - agent:*
ports:
  - port: 8080:80 # same as `--port '8080:80@loadbalancer'`
    nodeFilters:
      - loadbalancer
env:
  - envVar: bar=baz # same as `--env 'bar=baz@server:0'`
    nodeFilters:
      - server:0
registries: # define how registries should be created or used
  create: # creates a default registry to be used with the cluster; same as `--registry-create registry.localhost`
    name: registry.localhost
    host: "0.0.0.0"
    hostPort: "5000"
    proxy: # omit this to have a "normal" registry, set this to create a registry proxy (pull-through cache)
      remoteURL: https://registry-1.docker.io # mirror the DockerHub registry
      username: "" # unauthenticated
      password: "" # unauthenticated
    volumes:
      - /some/path:/var/lib/registry # persist registry data locally
  use:
    - k3d-myotherregistry:5000 # some other k3d-managed registry; same as `--registry-use 'k3d-myotherregistry:5000'`
  config: | # define contents of the `registries.yaml` file (or reference a file); same as `--registry-config /path/to/config.yaml`
    mirrors:
      "my.company.registry":
        endpoint:
          - http://my.company.registry:5000
hostAliases: # /etc/hosts style entries to be injected into /etc/hosts in the node containers and in the NodeHosts section in CoreDNS
  - ip: 1.2.3.4
    hostnames: 
      - my.host.local
      - that.other.local
  - ip: 1.1.1.1
    hostnames:
      - cloud.flare.dns
options:
  k3d: # k3d runtime settings
    wait: true # wait for cluster to be usable before returning; same as `--wait` (default: true)
    timeout: "60s" # wait timeout before aborting; same as `--timeout 60s`
    disableLoadbalancer: false # same as `--no-lb`
    disableImageVolume: false # same as `--no-image-volume`
    disableRollback: false # same as `--no-Rollback`
    loadbalancer:
      configOverrides:
        - settings.workerConnections=2048
  k3s: # options passed on to K3s itself
    extraArgs: # additional arguments passed to the `k3s server|agent` command; same as `--k3s-arg`
      - arg: "--tls-san=my.host.domain"
        nodeFilters:
          - server:*
    nodeLabels:
      - label: foo=bar # same as `--k3s-node-label 'foo=bar@agent:1'` -> this results in a Kubernetes node label
        nodeFilters:
          - agent:1
  kubeconfig:
    updateDefaultKubeconfig: true # add new cluster to your default Kubeconfig; same as `--kubeconfig-update-default` (default: true)
    switchCurrentContext: true # also set current-context to the new cluster's context; same as `--kubeconfig-switch-context` (default: true)
  runtime: # runtime (docker) specific options
    gpuRequest: all # same as `--gpus all`
    labels:
      - label: bar=baz # same as `--runtime-label 'bar=baz@agent:1'` -> this results in a runtime (docker) container label
        nodeFilters:
          - agent:1
    ulimits:
      - name: nofile
        soft: 26677
        hard: 26677
```

#
#### Handling multiple clusters
`k3d kubeconfig merge` let’s you specify one or more clusters via arguments or all via `--all`.
All kubeconfigs will then be merged into a single file if `--kubeconfig-merge-default` or `--output` is specified.
If none of those two flags was specified, a new file will be created per cluster and the merged path (e.g. `$HOME/.k3d/kubeconfig-cluster1.yaml:$HOME/.k3d/cluster2.yaml`) will be returned.
Note, that with multiple cluster specified, the `--kubeconfig-switch-context` flag will change the current context to the cluster which was last in the list.

#
#### local-path-provisioner in k3d
In k3d, the local paths that the local-path-provisioner uses (default is `/var/lib/rancher/k3s/storage`) lies inside the container’s filesystem, meaning that by default it’s not mapped somewhere e.g. in your user home directory for you to use. You’d need to map some local directory to that path to easily use the files inside this path: add `--volume $HOME/some/directory:/var/lib/rancher/k3s/storage@all` to your `k3d cluster create` command.

