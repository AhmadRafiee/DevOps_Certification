# Rancher Kubernetes Engine (RKE)
RKE is a CNCF-certified Kubernetes distribution that runs entirely within Docker containers. It solves the common frustration of installation complexity with Kubernetes by removing most host dependencies and presenting a stable path for deployment, upgrades, and rollbacks.
RKE is a fast, versatile Kubernetes installer that you can use to install Kubernetes on your Linux hosts. You can get started in a couple of quick and easy steps

## Download the RKE binary:
From your workstation, open a web browser and look up the latest available RKE release. You can click on the release notes link to go straight to that release or manually navigate to our RKE [Releases](https://github.com/rancher/rke/releases) page and download the latest available RKE installer

```bash
wget https://github.com/rancher/rke/releases/download/v1.7.3/rke_linux-amd64
chmod +x rke_linux-amd64
sudo mv rke_linux-amd64 /usr/local/bin/rke
```

## Creating the Cluster Configuration File
RKE uses a cluster configuration file, referred to as cluster.yml to determine what nodes will be in the cluster and how to deploy Kubernetes. There are [many configuration options](https://rke.docs.rancher.com/config-options) that can be set in the cluster.yml. In our example, we will be assuming the minimum of one node for your Kubernetes cluster.

There are two easy ways to create a cluster.yml:

  - Using our [minimal](https://rke.docs.rancher.com/example-yamls#minimal-clusteryml-example) `cluster.yml` and updating it based on the node that you will be using.
  - Using `rke config` to query for all the information needed.

### Using rke config
Run rke config to create a new cluster.yml in the current directory. This command will prompt you for all the information needed to build a cluster. See cluster configuration options for details on the various options.
```bash
rke config --name cluster.yml
```
**Other RKE Configuration Options**
You can create an empty template cluster.yml file by specifying the --empty flag.
```bash
rke config --empty --name cluster.yml
```
Instead of creating a file, you can print the generated configuration to stdout using the --print flag.
```bash
rke config --print
```

## Collect and Publish Images to your Private Registry
This section describes how to set up your private registry so that when you install Rancher, Rancher will pull all the required images from this registry.

By default, all images used to provision Kubernetes clusters or launch any tools in Rancher, e.g. monitoring, pipelines, alerts, are pulled from Docker Hub. In an air gapped installation of Rancher, you will need a private registry that is located somewhere accessible by your Rancher server. Then, you will load the registry with all the images.

Populating the private registry with images is the same process for installing Rancher with Docker and for installing Rancher on a Kubernetes cluster.

The steps in this section differ depending on whether or not you are planning to use Rancher to provision a downstream cluster with Windows nodes or not. By default, we provide the steps of how to populate your private registry assuming that Rancher will provision downstream Kubernetes clusters with only Linux nodes. But if you plan on provisioning any downstream Kubernetes clusters using Windows nodes, there are separate instructions to support the images needed.


#### Download Rancher script for management images:

**`rancher-images.txt`**	This file contains a list of images needed to install Rancher, provision clusters and user Rancher tools.
**`rancher-save-images.sh`**	This script pulls all the images in the rancher-images.txt from Docker Hub and saves all of the images as rancher-images.tar.gz.
**`rancher-load-images.sh`**	This script loads images from the rancher-images.tar.gz file and pushes them to your private registry.


Get scripts for download, save and load images to registry:
```bash
# download rancher-images.txt list:
wget https://github.com/rancher/rancher/releases/download/v2.10.3-alpha2/rancher-images.txt

# download rancher-save-images script:
wget https://github.com/rancher/rancher/releases/download/v2.10.3-alpha2/rancher-save-images.sh

# download rancher-load-images script:
wget https://github.com/rancher/rancher/releases/download/v2.10.3-alpha2/rancher-load-images.sh
```

#### Get all kubernetes version support image list
```bash
# list all kubernetes version support
rke config --list-version

# Create a list of all images for one version
rke config --list-version --system-images > rancher-images.txt

# Create a list of all images for all version
rke config --list-version --all --system-images > rancher-images.txt
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

#### Populate the private registry
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

## General Linux Requirements

**SSH user** - The SSH user used for node access must be a member of the docker group on the node:
```bash
usermod -aG docker <user_name>
```

**Swap config:** Swap should be disabled on any worker nodes
```bash
sudo swapoff -a
```

**sysctl config:** Following sysctl settings must be applied
```bash
net.bridge.bridge-nf-call-iptables=1
```

**SSH Server Configuration:** Your SSH server system-wide configuration file, located at `/etc/ssh/sshd_config`, must include this line that allows TCP forwarding:
```bash
AllowTcpForwarding yes
```

## Installing Docker
Docker is required to be installed on nodes where the Rancher server will be installed with Helm on an RKE cluster or with Docker. Docker is not required for RKE2 or K3s clusters.

There are a couple of options for installing Docker. One option is to refer to the official Docker documentation about how to install Docker on Linux. The steps will vary based on the Linux distribution.

Another option is to use one of Rancher's Docker installation scripts, which are available for most recent versions of Docker. Rancher has installation scripts for every version of upstream Docker that Kubernetes supports.

For information on which Docker versions were tested with your version of RKE, refer to the [support matrix](https://www.suse.com/suse-rke1/support-matrix/all-supported-versions/rke1-v1-31/) for installing Rancher on RKE.

For example, this command could be used to install on one of the main Linux distributions, such as SUSE Linux Enterprise or Ubuntu:
```bash
curl https://releases.rancher.com/install-docker/<version-number>.sh | sh
```

Install specific docker version and post install on all nodes
```bash
which docker || https://releases.rancher.com/install-docker/27.5.1.sh
sudo usermod -aG docker $USER
apt-mark hold docker-ce
```

**Checking the Installed Docker Version** Confirm that a Kubernetes supported version of Docker is installed on your machine, by running
```bash
docker version --format '{{.Server.Version}}'.
```

## Sample `cluster.yml` file
```bash
cat <<EOF >> cluster.yml
nodes:
  - address: "192.168.200.11"
    port: 8090
    role:
      - "etcd"
      - "controlplane"
      - "worker"
    user: root
    hostname_override: "master1"
    docker_socket: /var/run/docker.sock

  - address: "192.168.200.12"
    port: 8090
    role:
      - "etcd"
      - "controlplane"
      - "worker"
    user: root
    hostname_override: "master2"
    docker_socket: /var/run/docker.sock

  - address: "192.168.200.13"
    port: 8090
    role:
      - "etcd"
      - "controlplane"
      - "worker"
    user: root
    hostname_override: "master3"
    docker_socket: /var/run/docker.sock

  - address: "192.168.200.14"
    port: 8090
    role:
      - "worker"
    user: root
    hostname_override: "worker1"
    docker_socket: /var/run/docker.sock

  - address: "192.168.200.15"
    port: 8090
    role:
      - "worker"
    user: root
    hostname_override: "worker2"
    docker_socket: /var/run/docker.sock

  - address: "192.168.200.16"
    port: 8090
    role:
      - "worker"
    user: root
    hostname_override: "worker3"
    docker_socket: /var/run/docker.sock

# If set to true, RKE will not fail when unsupported Docker version
ignore_docker_version: true

# The Kubernetes version used. The default versions of Kubernetes are tied to specific versions of the system images.
kubernetes_version: "v1.31.5-rancher1-1"

# Set the name of the Kubernetes cluster
cluster_name: "MeCan"

# List of registry credentials
private_registries:
  - url: registry.mecan.ir
    user: MeCan
    password:
    is_default: true

services:
  etcd:
    snapshot: true
    backup_config:
      interval_hours: 4
      retention: 10

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
    always_pull_images: true

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
    - "192.168.200.10"
    - "192.168.200.11"
    - "192.168.200.12"
    - "192.168.200.13"
    - "master.kube.mecan.ir"
    - "vip.kube.mecan.ir"
    - "master1.kube.mecan.ir"
    - "master2.kube.mecan.ir"
    - "master3.kube.mecan.ir"
    - "master"
    - "master1"
    - "master2"
    - "master3"

authorization:
  mode: rbac

# Specify monitoring provider (metrics-server)
monitoring:
  provider: metrics-server
  # Available as of v1.1.0
  update_strategy:
    strategy: RollingUpdate
    rollingUpdate:
      maxUnavailable: 8
EOF
```

## Run RKE
After configuring cluster.yml, bring up your Kubernetes cluster:
```bash
rke up --config ./cluster.yml
```

## Save Your Files
Important The files mentioned below are needed to maintain, troubleshoot and upgrade your cluster.

Save a copy of the following files in a secure location:

  - **`cluster.yml`**: The RKE cluster configuration file.
  - **`kube_config_cluster.yml`**: The Kubeconfig file for the cluster, this file contains credentials for full access to the cluster.
  - **`cluster.rkestate`**: The Kubernetes Cluster State file, this file contains the current state of the cluster including the RKE configuration and the certificates.

The Kubernetes Cluster State file is only created when using RKE v0.2.0 or higher.



## One-time Snapshots
To save a snapshot of etcd from each etcd node in the cluster config file, run the `rke etcd snapshot-save` command.

The snapshot is saved in `/opt/rke/etcd-snapshots`.

When running the command, an additional container is created to take the snapshot. When the snapshot is completed, the container is automatically removed.

The one-time snapshot can be uploaded to a S3 compatible backend by using the additional options to specify the S3 backend.

To create a local one-time snapshot, run:
```bash
rke etcd snapshot-save --config cluster.yml --name snapshot-name
```

**Result:** The snapshot is saved in `/opt/rke/etcd-snapshots`.

To save a one-time snapshot to S3, run:
```bash
rke etcd snapshot-save \
--config cluster.yml \
--name snapshot-name \
--s3 \
--access-key S3_ACCESS_KEY \
--secret-key S3_SECRET_KEY \
--bucket-name s3-bucket-name \
--folder s3-folder-name \
--s3-endpoint s3.amazonaws.com
```
**Result:** The snapshot is saved in `/opt/rke/etcd-snapshots` as well as uploaded to the S3 backend.

## Recurring Snapshots
To schedule automatic recurring etcd snapshots, you can enable the etcd-snapshot service with extra configuration options. etcd-snapshot runs in a service container alongside the etcd container. By default, the etcd-snapshot service takes a snapshot for every node that has the etcd role and stores them to local disk in `/opt/rke/etcd-snapshots`.

If you set up the options for S3, the snapshot will also be uploaded to the S3 backend.

**Snapshot Service Logging:** When a cluster is launched with the etcd-snapshot service enabled, you can view the `etcd-rolling-snapshots` logs to confirm backups are being created automatically.

```bash
docker logs etcd-rolling-snapshots

time="2018-05-04T18:39:16Z" level=info msg="Initializing Rolling Backups" creation=1m0s retention=24h0m0s
time="2018-05-04T18:40:16Z" level=info msg="Created backup" name="2018-05-04T18:40:16Z_etcd" runtime=108.332814ms
time="2018-05-04T18:41:16Z" level=info msg="Created backup" name="2018-05-04T18:41:16Z_etcd" runtime=92.880112ms
time="2018-05-04T18:42:16Z" level=info msg="Created backup" name="2018-05-04T18:42:16Z_etcd" runtime=83.67642ms
time="2018-05-04T18:43:16Z" level=info msg="Created backup" name="2018-05-04T18:43:16Z_etcd" runtime=86.298499ms
```

## [Restoring from Backup](https://rke.docs.rancher.com/etcd-snapshots/restoring-from-backup)
## [Example Scenarios](https://rke.docs.rancher.com/etcd-snapshots/example-scenarios)


## [Adding/Removing Nodes](https://rke.docs.rancher.com/managing-clusters)
RKE supports adding/removing nodes for worker and controlplane hosts.

In order to add additional nodes, you update the original `cluster.yml` file with any additional nodes and specify their role in the Kubernetes cluster.
In order to remove nodes, remove the node information from the nodes list in the original `cluster.yml`.
After you've made changes to add/remove nodes, run rke up with the updated `cluster.yml`.

#### Adding/Removing Worker Nodes
You can add/remove only worker nodes, by running `rke up --update-only`. This will ignore everything else in the `cluster.yml` except for any worker nodes.

## Upgrades
After RKE has deployed Kubernetes, you can upgrade the versions of the components in your Kubernetes cluster, the definition of the Kubernetes services or the add-ons.

The default Kubernetes version for each RKE version can be found in the release notes accompanying the RKE download. These can also be checked with the rke CLI
You can also select a newer version of Kubernetes to install for your cluster but please avoid skipping minor versions, as this can increase the chances of an issue due to accumulated changes, as per the upstream Kubernetes documentation
In case the Kubernetes version is defined in the `kubernetes_version` directive and under the `system_images` directive, the `system_images` configuration will take precedence over the `kubernetes_version`.

#### Prerequisites
  - Ensure that any `system_images` configuration is absent from the `cluster.yml`. The Kubernetes version should only be listed under the `system_images` directive if an unsupported version is being used. Refer to Kubernetes version precedence for more information.
  - Ensure that the correct files to manage Kubernetes cluster state are present in the working directory. Refer to the tabs below for the required files, which differ based on the RKE version.


## Removing Kubernetes Components from Nodes
In order to remove the Kubernetes components from nodes, you use the `rke remove` command.

**danger** This command is irreversible and will destroy the Kubernetes cluster, including etcd snapshots on S3. If there is a disaster and your cluster is inaccessible, refer to the process for restoring your cluster from a snapshot.

Clean each host from the directories left by the services:
  - /etc/kubernetes/ssl
  - /var/lib/etcd
  - /etc/cni
  - /opt/cni
  - /var/run/calico

## [Kubernetes Configuration Options](https://rke.docs.rancher.com/config-options)
