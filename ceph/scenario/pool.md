# Pools
- [Pools](#pools)
    - [List pools:](#list-pools)
    - [Creating pools:](#creating-pools)
    - [Description:](#description)
    - [Creating a replicated pool](#creating-a-replicated-pool)
    - [Setting pool quota:](#setting-pool-quota)
    - [Deleting a pool:](#deleting-a-pool)
    - [Renaming a pool:](#renaming-a-pool)
    - [Migrating a pool](#migrating-a-pool)
    - [Viewing pool statistics](#viewing-pool-statistics)
    - [Setting pool values](#setting-pool-values)
    - [Enabling a client application](#enabling-a-client-application)

### List pools:
To list your cluster’s pools, run:
```bash
ceph osd lspools
```

### Creating pools:
Based on the requirement, you can create a replicated pool, an erasure-coded pool, or a bulk pool.

### Description:
  - **POOL_NAME:** The name of the pool. It must be unique
  - **PG_NUM:** The total number of placement groups for the pool. For more information about calculating a suitable number, see Placement groups and Ceph Placement Groups (PGs) per Pool Calculator on the Red Hat Customer Portal. The default value 8 is not suitable for most systems.
  - **PGP_NUM:** The total number of placement groups for placement purposes. This value must be equal to the total number of placement groups, except for placement group splitting scenarios.
  - **replicated or erasure:** The pool type can be either replicated to recover from lost OSDs by keeping multiple copies of the objects or erasure to get a generalized RAID5 capability. The replicated pools require more raw storage but implement all Ceph operations. The erasure-coded pools require less raw storage but implement only a subset of the available operations.
  - **crush-rule-name:** The name of the crush rule for the pool. The rule must exist. For replicated pools, the name is the rule that is specified by the osd_pool_default_crush_rule configuration setting. For erasure-coded pools the name is erasure-code if you specify the default erasure code profile or POOL_NAME otherwise. Ceph creates this rule with the specified name implicitly if the rule doesn’t exist.
  - **expected-num-objects:** The expected number of objects for the pool. Ceph splits the placement groups at pool creation time to avoid the latency impact to perform runtime directory splitting.
  - **erasure-code-profile:** For erasure-coded pools only. Use the erasure code profile. It must be an existing profile as defined by the osd erasure-code-profile set variable in the Ceph configuration file. For more information, see Erasure code profiles.
  - **size:** Specifies the number of replicas for objects in the pool. For more information, see Setting the number of object replicas. Applicable for the replicated pools only.
  - **min_size:** Specifies the minimum number of replicas required for I/O. For more information, see Setting the number of object replicas. For erasure-coded pools, this should be set to a value greater than k. If I/O is allowed at the value k, then there is no redundancy and data is lost in the event of a permanent OSD failure. For more information, see Erasure code pools overview.

### Creating a replicated pool
```bash
ceph osd pool create POOL_NAME PG_NUM PGP_NUM [replicated] [CRUSH_RULE_NAME] [EXPECTED_NUMBER_OBJECTS]
```

**Creating an erasure-coded pool**
```bash
ceph osd pool create POOL_NAME PG_NUM PGP_NUM [erasure] ERASURE_CODE_PROFILE
         [CRUSH_RULE_NAME] [EXPECTED_NUMBER_OBJECTS]
```

Creating a bulk pool
```bash
ceph osd pool create POOL_NAME [--bulk]
```

### Setting pool quota:
You can set pool quotas for the maximum number of bytes or the maximum number of objects per pool or for both.

:
```bash
ceph osd pool set-quota POOL_NAME [max_objects OBJECT_COUNT>] [max_bytes BYTES]
```
Example
```bash
ceph osd pool set-quota data max_objects 10000
```
To remove a quota, set its value to 0.

### Deleting a pool:
To delete a pool, run:


```bash
ceph osd pool delete POOL_NAME [POOL_NAME --yes-i-really-really-mean-it]
```
**Important:** To protect data, storage administrators cannot delete pools by default. Set the `mon_allow_pool_delete` configuration option before deleting pools.

If a pool has its own rule, consider removing it after deleting the pool. If a pool has users strictly for its own use, consider deleting those users after deleting the pool.

### Renaming a pool:
To rename a pool, run:

```bash
ceph osd pool rename CURRENT_POOL_NAME NEW_POOL_NAME
```
If you rename a pool and you have per-pool capabilities for an authenticated user, you must update the user’s capabilities (that is, caps) with the new pool name.

### Migrating a pool
Sometimes it is necessary to migrate all objects from one pool to another. This is done in cases such as needing to change parameters that cannot be modified on a specific pool. For example, needing to reduce the number of placement groups of a pool.

The migration methods described for Ceph Block Device are more recommended than those documented here. using the cppool does not preserve all snapshots and snapshot related metadata, resulting in an unfaithful copy of the data. For example, copying an RBD pool does not completely copy the image. In this case, snaps are not present and will not work properly. The cppool also does not preserve the user_version field that some librados users may rely on.
If migrating a pool is necessary and your user workloads contain images other than Ceph Block Devices, continue with one of the procedures documented here.

**Before you begin**
  - If using the rados cppool command:
    - Read-only access to the pool is required.
    - Only use this command if you do not have RBD images and its snaps and user_version consumed by librados.
  -If using the local drive RADOS commands, verify that sufficient cluster space is available. Two, three, or more copies of data will be present as per pool replication factor.

**Migrating directly**
Copy all objects with the rados cppool command.
```bash
ceph osd pool create NEW_POOL PG_NUM [ <other new pool parameters> ]
rados cppool SOURCE_POOL NEW_POOL
ceph osd pool rename SOURCE_POOL NEW_SOURCE_POOL_NAME
ceph osd pool rename NEW_POOL SOURCE_POOL
# For example,
ceph osd pool create pool1 250
rados cppool pool2 pool1
ceph osd pool rename pool2 pool3
ceph osd pool rename pool1 pool2
```

### Viewing pool statistics
To show a pool’s utilization statistics, run the following command:

```bash
rados df
```

### Setting pool values
To set a value to a pool, run the following command:
```bash
ceph osd pool set POOL_NAME KEY VALUE
```
For more information about the available key-value pairs, see Pool values.

**Getting pool values**
To get a value from a pool, run the following command:
```bash
ceph osd pool get POOL_NAME KEY
```
For more information about the available key-value pairs, see Pool values.

### Enabling a client application
IBM Storage Ceph provides additional protection for pools to prevent unauthorized types of clients from writing data to the pool. This means that system administrators must expressly enable pools to receive I/O operations from Ceph Block Device, Ceph Object Gateway, Ceph Filesystem or for a custom application.

To enable a client application to conduct I/O operations on a pool, execute the following:

```bash
ceph osd pool application enable POOL_NAME APP {--yes-i-really-mean-it}
```

**Disabling a client application**
To disable a client application from conducting I/O operations on a pool, run the following:
```bash
ceph osd pool application disable POOL_NAME APP {--yes-i-really-mean-it}
```

**Where APP is:**
  - cephfs for the Ceph Filesystem.
  - rbd for the Ceph Block Device
  - rgw for the Ceph Object Gateway