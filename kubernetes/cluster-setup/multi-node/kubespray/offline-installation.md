# Deploy a Production Ready Kubernetes Cluster with Kubespray - Offline environment

In case your servers don't have access to the internet directly (for example
when deploying on premises with security constraints), you need to get the
following artifacts in advance from another environment where has access to the internet.

* Some static files (zips and binaries)
* OS packages (rpm/deb files)
* Container images used by Kubespray. Exhaustive list depends on your setup
* [Optional] Python packages used by Kubespray (only required if your OS doesn't provide all python packages/versions
  listed in `requirements.txt`)
* [Optional] Helm chart files (only required if `helm_enabled=true`)

Then you need to setup the following services on your offline environment:

* an HTTP reverse proxy/cache/mirror to serve some static files (zips and binaries)
* an internal Yum/Deb repository for OS packages
* an internal container image registry that need to be populated with all container images used by Kubespray
* [Optional] an internal PyPi server for python packages used by Kubespray
* [Optional] an internal Helm registry for Helm chart files

You can get artifact lists with [generate_list.sh](/contrib/offline/generate_list.sh) script.
In addition, you can find some tools for offline deployment under [contrib/offline](/contrib/offline/README.md).

## Configure Inventory

Once all artifacts are accessible from your internal network, **adjust** the following variables
in [your inventory](/inventory/sample/group_vars/all/offline.yml) to match your environment:

```yaml
## Global Offline settings
files_repo: "https://repo.mecan.ir/repository/kube"

### If using Debian
debian_repo: "https://repo.mecan.ir/repository/debian"
debian_docker_repo: "https://repo.mecan.ir/repository/debian-docker"

### If using Ubuntu
ubuntu_repo: "https://repo.mecan.ir/repository/ubuntu"
ubuntu_docker_repo: "https://repo.mecan.ir/repository/ubuntu-docker"

## Container Registry overrides
kube_image_repo: "k8s.mecan.ir"
gcr_image_repo: "gcr.mecan.ir"
github_image_repo: "github.mecan.ir"
docker_image_repo: "hub.mecan.ir"
quay_image_repo: "quay.mecan.ir"

## Kubernetes components
kubeadm_download_url: "{{ files_repo }}/dl.k8s.io/release/{{ kube_version }}/bin/linux/{{ image_arch }}/kubeadm"
kubectl_download_url: "{{ files_repo }}/dl.k8s.io/release/{{ kube_version }}/bin/linux/{{ image_arch }}/kubectl"
kubelet_download_url: "{{ files_repo }}/dl.k8s.io/release/{{ kube_version }}/bin/linux/{{ image_arch }}/kubelet"

## CNI Plugins
cni_download_url: "{{ files_repo }}/github.com/containernetworking/plugins/releases/download/{{ cni_version }}/cni-plugins-linux-{{ image_arch }}-{{ cni_version }}.tgz"

## cri-tools
crictl_download_url: "{{ files_repo }}/github.com/kubernetes-sigs/cri-tools/releases/download/{{ crictl_version }}/crictl-{{ crictl_version }}-{{ ansible_system | lower }}-{{ image_arch }}.tar.gz"

## [Optional] etcd: only if you use etcd_deployment=host
etcd_download_url: "{{ files_repo }}/github.com/etcd-io/etcd/releases/download/{{ etcd_version }}/etcd-{{ etcd_version }}-linux-{{ image_arch }}.tar.gz"

# [Optional] Calico: If using Calico network plugin
calicoctl_download_url: "{{ files_repo }}/github.com/projectcalico/calico/releases/download/{{ calico_ctl_version }}/calicoctl-linux-{{ image_arch }}"
# [Optional] Calico with kdd: If using Calico network plugin with kdd datastore
calico_crds_download_url: "{{ files_repo }}/github.com/projectcalico/calico/archive/{{ calico_version }}.tar.gz"

# [Optional] Cilium: If using Cilium network plugin
ciliumcli_download_url: "{{ files_repo }}/github.com/cilium/cilium-cli/releases/download/{{ cilium_cli_version }}/cilium-linux-{{ image_arch }}.tar.gz"

# [Optional] helm: only if you set helm_enabled: true
helm_download_url: "{{ files_repo }}/get.helm.sh/helm-{{ helm_version }}-linux-{{ image_arch }}.tar.gz"

# [Optional] crun: only if you set crun_enabled: true
crun_download_url: "{{ files_repo }}/github.com/containers/crun/releases/download/{{ crun_version }}/crun-{{ crun_version }}-linux-{{ image_arch }}"

# [Optional] kata: only if you set kata_containers_enabled: true
kata_containers_download_url: "{{ files_repo }}/github.com/kata-containers/kata-containers/releases/download/{{ kata_containers_version }}/kata-static-{{ kata_containers_version }}-{{ ansible_architecture }}.tar.xz"

# [Optional] cri-dockerd: only if you set container_manager: docker
cri_dockerd_download_url: "{{ files_repo }}/github.com/Mirantis/cri-dockerd/releases/download/v{{ cri_dockerd_version }}/cri-dockerd-{{ cri_dockerd_version }}.{{ image_arch }}.tgz"

# [Optional] runc: if you set container_manager to containerd or crio
runc_download_url: "{{ files_repo }}/github.com/opencontainers/runc/releases/download/{{ runc_version }}/runc.{{ image_arch }}"

# [Optional] containerd: only if you set container_runtime: containerd
containerd_download_url: "{{ files_repo }}/github.com/containerd/containerd/releases/download/v{{ containerd_version }}/containerd-{{ containerd_version }}-linux-{{ image_arch }}.tar.gz"
nerdctl_download_url: "{{ files_repo }}/github.com/containerd/nerdctl/releases/download/v{{ nerdctl_version }}/nerdctl-{{ nerdctl_version }}-{{ ansible_system | lower }}-{{ image_arch }}.tar.gz"

# [Optional] Krew: only if you set krew_enabled: true
krew_download_url: "{{ files_repo }}/github.com/kubernetes-sigs/krew/releases/download/{{ krew_version }}/krew-{{ host_os }}_{{ image_arch }}.tar.gz"

### If using Debian
### Docker
docker_debian_repo_base_url: "{{ debian_docker_repo }}/"
docker_debian_repo_gpgkey: "{{ debian_docker_repo }}/gpg"
### Containerd
containerd_debian_repo_base_url: "{{ debian_docker_repo }}/"
containerd_debian_repo_gpgkey: "{{ debian_docker_repo }}/gpg"

### If using Ubuntu
### Docker
docker_ubuntu_repo_base_url: "{{ ubuntu_docker_repo }}/"
docker_ubuntu_repo_gpgkey: "{{ ubuntu_docker_repo }}/gpg"
### Containerd
containerd_ubuntu_repo_base_url: "{{ ubuntu_docker_repo }}/"
containerd_ubuntu_repo_gpgkey: "{{ ubuntu_docker_repo }}/gpg"
```

For the OS specific settings, just define the one matching your OS.
If you use the settings like the one above, you'll need to define in your inventory the following variables:

* `registry_host`: Container image registry. If you _don't_ use the same repository path for the container images that
  the ones defined
  in [kubesprays-defaults's role defaults](https://github.com/kubernetes-sigs/kubespray/blob/master/roles/kubespray-defaults/defaults/main/download.yml)
  , you need to override the `*_image_repo` for these container images. If you want to make your life easier, use the
  same repository path, you won't have to override anything else.
* `registry_addr`: Container image registry, but only have [domain or ip]:[port].
* `files_repo`: HTTP webserver or reverse proxy that is able to serve the files listed above. Path is not important, you
  can store them anywhere as long as it's accessible by kubespray. It's recommended to use `*_version` in the path so
  that you don't need to modify this setting everytime kubespray upgrades one of these components.
* `yum_repo`/`debian_repo`/`ubuntu_repo`: OS package repository depending on your OS, should point to your internal
  repository. Adjust the path accordingly.

## Install Kubespray Python Packages

### Recommended way: Kubespray Container Image

The easiest way is to use [kubespray container image](https://quay.io/kubespray/kubespray) as all the required packages
are baked in the image.
Just copy the container image in your private container image registry and you are all set!

### Manual installation

Look at the `requirements.txt` file and check if your OS provides all packages out-of-the-box (Using the OS package
manager). For those missing, you need to either use a proxy that has Internet access (typically from a DMZ) or setup a
PyPi server in your network that will host these packages.

If you're using an HTTP(S) proxy to download your python packages:

```bash
sudo pip install --proxy=https://[username:password@]proxyserver:port -r requirements.txt
```

When using an internal PyPi server:

```bash
# If you host all required packages
pip install -i https://pypiserver/pypi -r requirements.txt

# If you only need the ones missing from the OS package manager
pip install -i https://pypiserver/pypi package_you_miss
```

## Run Kubespray as usual

Once all artifacts are in place and your inventory properly set up, you can run kubespray with the
regular `cluster.yaml` command:

```bash
ansible-playbook -i inventory/my_airgap_cluster/hosts.yaml -b cluster.yml
```

If you use [Kubespray Container Image](#recommended-way:-kubespray-container-image), you can mount your inventory inside
the container:

```bash
docker run --rm -it -v path_to_inventory/my_airgap_cluster:inventory/my_airgap_cluster myprivateregisry.com/kubespray/kubespray:v2.14.0 ansible-playbook -i inventory/my_airgap_cluster/hosts.yaml -b cluster.yml
```