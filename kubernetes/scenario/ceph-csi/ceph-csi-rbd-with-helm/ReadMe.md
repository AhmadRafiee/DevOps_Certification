
# ceph-csi-rbd on kubernetes cluster

### CREATE A POOL
By default, Ceph block devices use the rbd pool. Create a pool for Kubernetes volume storage. Ensure your Ceph cluster is running, then create the pool.
```bash
ceph osd pool create kubernetes

# Check pool list
ceph osd pool ls
```

See Create a Pool for details on specifying the number of placement groups for your pools, and Placement Groups for details on the number of placement groups you should set for your pools. A newly created pool must be initialized prior to use. Use the rbd tool to initialize the pool:
```bash
rbd pool init kubernetes
```

### SETUP CEPH CLIENT AUTHENTICATION
Create a new user for Kubernetes and ceph-csi. Execute the following and record the generated key:
```bash
ceph auth get-or-create client.kubernetes mon 'profile rbd' osd 'profile rbd pool=kubernetes' mgr 'profile rbd pool=kubernetes'
```

**sample output:**
```bash
rofile rbd pool=kubernetes'
[client.kubernetes]
	key = AQC2zCxnF/FoFRAAlMLvC9unRu2tmAp99V/bCQ==
```

The ceph-csi requires a ConfigMap object stored in Kubernetes to define the the Ceph monitor addresses for the Ceph cluster. Collect both the Ceph cluster unique fsid and the monitor addresses:
```bash
ceph mon dump
```

**sample output:**
```bash
epoch 7
fsid 08604626-968a-11ef-bed8-005056abbe66
last_changed 2024-10-30T07:23:08.838168+0000
created 2024-10-30T06:41:52.186084+0000
min_mon_release 18 (reef)
election_strategy: 1
0: [v2:192.168.200.21:3300/0,v1:192.168.200.21:6789/0] mon.mon1
1: [v2:192.168.200.22:3300/0,v1:192.168.200.22:6789/0] mon.mon2
2: [v2:192.168.200.23:3300/0,v1:192.168.200.23:6789/0] mon.mon3
dumped monmap epoch 7
```

### add helm repository and install ceph-csi. [link](https://artifacthub.io/packages/helm/ceph-csi/ceph-csi-rbd)

**get all values on helm repo:**
```bash
helm get values ceph-csi
```

**change helm values on helm.rbd.values file:**

  - **clusterID**
  - **userID**
  - **userKey**
  - **pool**
  - **monitor address**

```bash
# Add chart repository to install helm charts from it
helm repo add ceph-csi https://ceph.github.io/csi-charts

# To install the Chart into your Kubernetes cluster
helm upgrade --install ceph-csi ceph-csi/ceph-csi-rbd \
    --namespace ceph-csi-rbd \
    -f helm.rbd.values \
    --create-namespace
```

### Smoke test
A PersistentVolumeClaim is a request for abstract storage resources by a user. The PersistentVolumeClaim would then be associated to a Pod resource to provision a PersistentVolume, which would be backed by a Ceph block image. An optional volumeMode can be included to select between a mounted file system (default) or raw block device-based volume.

Using ceph-csi, specifying Filesystem for volumeMode can support both ReadWriteOnce and ReadOnlyMany accessMode claims, and specifying Block for volumeMode can support ReadWriteOnce, ReadWriteMany, and ReadOnlyMany accessMode claims.

For example, to create a block-based PersistentVolumeClaim that utilizes the ceph-csi-based StorageClass created above, the following YAML can be used to request raw block storage from the csi-rbd-sc StorageClass:

```bash
kubectl apply -f test-pvc-and-pod.yml
kubectl get pod
kubectl get pvc
```

### To list block devices in the rbd pool, run the following command:
```bash
rbd ls {poolname}

rbd ls kubernetes
```