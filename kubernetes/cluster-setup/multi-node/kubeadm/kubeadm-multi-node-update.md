# [Upgrading kubeadm clusters](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/)
This page explains how to upgrade a Kubernetes cluster created with kubeadm from version 1.27.x to version 1.28.x, and from version 1.28.x to 1.28.y (where y > x). Skipping MINOR versions when upgrading is unsupported. For more details, please visit Version Skew Policy.

[Upgrading a kubeadm cluster from 1.26 to 1.27](https://v1-27.docs.kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/)
[Upgrading a kubeadm cluster from 1.25 to 1.26](https://v1-26.docs.kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/)
[Upgrading a kubeadm cluster from 1.24 to 1.25](https://v1-25.docs.kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/)
[Upgrading a kubeadm cluster from 1.23 to 1.24](https://v1-24.docs.kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/)


##### The upgrade workflow at high level is the following:

1. Upgrade a primary control plane node.
2. Upgrade additional control plane nodes.
3. Upgrade worker nodes.


##### Before you begin
- Make sure you read the release notes carefully.
- The cluster should use a static control plane and etcd pods or external etcd.
- Make sure to back up any important components, such as app-level state stored in a database. kubeadm upgrade does not touch your workloads, only components internal to Kubernetes, but backups are always a best practice.
- Swap must be disabled.

##### Find the latest patch release for Kubernetes 1.28 using the OS package manager:
```bash
apt-cache madison kubeadm
apt-cache policy kubeadm
# Find the latest 1.28 version in the list.
# It should look like 1.28.x-*, where x is the latest patch.
```

##### Upgrading control plane nodes

1. Upgrade kubeadm:
```bash
# # replace x in 1.28.x-* with the latest patch version
apt-mark unhold kubeadm && \
apt-get update && apt-get install -y kubeadm='1.28.x-*' && \
apt-mark hold kubeadm
```

2. Verify that the download works and has the expected version:

```bash
kubeadm version
```

3. Verify the upgrade plan:

```bash
kubeadm upgrade plan
```
This command checks that your cluster can be upgraded, and fetches the versions you can upgrade to. It also shows a table with the component config version states.

4. Choose a version to upgrade to, and run the appropriate command. For example:
```bash
# replace x with the patch version you picked for this upgrade
sudo kubeadm upgrade apply v1.28.x
```

Once the command finishes you should see:
```bash
[upgrade/successful] SUCCESS! Your cluster was upgraded to "v1.28.x". Enjoy!

[upgrade/kubelet] Now that your control plane is upgraded, please proceed with upgrading your kubelets if you haven't already done so.
```

5. Manually upgrade your CNI provider plugin.
Your Container Network Interface (CNI) provider may have its own upgrade instructions to follow. Check the addons page to find your CNI provider and see whether additional upgrade steps are required.
This step is not required on additional control plane nodes if the CNI provider runs as a DaemonSet.

##### For the other control plane nodes:
Same as the first control plane node but use:

```bash
sudo kubeadm upgrade node
```
instead of:
```bash
sudo kubeadm upgrade apply
```
Also calling kubeadm upgrade plan and upgrading the CNI provider plugin is no longer needed.

##### Drain the node:
- Prepare the node for maintenance by marking it unschedulable and evicting the workloads:
```bash
# replace <node-to-drain> with the name of your node you are draining
kubectl drain <node-to-drain> --ignore-daemonsets
```

##### Upgrade kubelet and kubectl:
- Upgrade the kubelet and kubectl
```bash
# replace x in 1.28.x-* with the latest patch version
apt-mark unhold kubelet kubectl && \
apt-get update && apt-get install -y kubelet='1.28.x-*' kubectl='1.28.x-*' && \
apt-mark hold kubelet kubectl
```

- Restart the kubelet:
```bash
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

##### Uncordon the node:
- Bring the node back online by marking it schedulable:
```bash
# replace <node-to-drain> with the name of your node
kubectl uncordon <node-to-drain>
```

##### Upgrade worker nodes:
##### The upgrade procedure on worker nodes should be executed one node at a time or few nodes at a time, without compromising the minimum required capacity for running your workloads.

- Upgrade kubeadm:
```bash
# replace x in 1.28.x-00 with the latest patch version
apt-mark unhold kubeadm && \
apt-get update && apt-get install -y kubeadm=1.28.x-00 && \
apt-mark hold kubeadm
```

##### Call "kubeadm upgrade"
- For worker nodes this upgrades the local kubelet configuration:
```bash
sudo kubeadm upgrade node
```
- Drain the node
```bash
# replace <node-to-drain> with the name of your node you are draining
kubectl drain <node-to-drain> --ignore-daemonsets
```

- Upgrade kubelet and kubectl
```bash
# replace x in 1.28.x-00 with the latest patch version
apt-mark unhold kubelet kubectl && \
apt-get update && apt-get install -y kubelet=1.28.x-00 kubectl=1.28.x-00 && \
apt-mark hold kubelet kubectl
-
```
- Restart the kubelet:
```bash
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

##### Uncordon the node
- Bring the node back online by marking it schedulable:
```bash
# replace <node-to-drain> with the name of your node
kubectl uncordon <node-to-drain>
```

##### Verify the status of the cluster
After the kubelet is upgraded on all nodes verify that all nodes are available again by running the following command from anywhere kubectl can access the cluster:
```bash
kubectl get nodes
```
The STATUS column should show Ready for all your nodes, and the version number should be updated.