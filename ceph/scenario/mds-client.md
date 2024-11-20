# MDS client and usage


- [MDS client and usage](#mds-client-and-usage)
    - [Install Ceph Client Packages:](#install-ceph-client-packages)
    - [Retrieve Ceph Configuration:](#retrieve-ceph-configuration)
    - [Create the MDS User:](#create-the-mds-user)
    - [Mount CephFS:](#mount-cephfs)
    - [Interact with CephFS:](#interact-with-cephfs)
    - [Unmount CephFS:](#unmount-cephfs)


![mds-design](../images/mds-design.png)

**Metadata Server client**
To configure and use an MDS (Metadata Server) client in Linux for the Ceph distributed storage system, you can follow these steps:

### Install Ceph Client Packages:
Ensure that the Ceph client packages are installed on the Linux system. The package names may vary depending on the Linux distribution. For example, on Ubuntu, you can use the following command to install the packages:
```bash
sudo apt-get install ceph-fuse
```

### Retrieve Ceph Configuration:
Obtain the Ceph configuration file (ceph.conf) from the Ceph cluster or the cluster administrator. Place the configuration file in a suitable location on the Linux system (e.g., /etc/ceph/ceph.conf).

Get minimal config from ceph:
```bash
ceph config generate-minimal-conf
```

### Create the MDS User:
Run the following command to create a new Ceph user for the MDS service. This user needs to have the proper capabilities (i.e., access to the monitor, metadata server, and OSDs):

```bash
ceph auth get-or-create client.<mds_name> mon 'allow profile mds' osd 'allow rwx pool=cephfs_data' mds 'allow'
```

### Mount CephFS:
Create a mount point directory on the Linux system where you want to access the CephFS.
Use the ceph-fuse command to mount the CephFS on the specified mount point. The command should include the path to the Ceph configuration file and the mount point directory. For example:
```bash
sudo ceph-fuse -m <MONITOR_IP>:6789 /path/to/mount/point -c /etc/ceph/ceph.conf
```
Replace `<MONITOR_IP>` with the IP address of one of the Ceph monitors.

--keyring=/etc/ceph/ceph.client.admin.keyring
--id=client_name
--no-mon-config

### Interact with CephFS:
Once the CephFS is mounted, you can use standard file system commands to interact with the file system.
Navigate to the mount point directory and use commands like ls, cd, mkdir, touch, rm, etc., to manage files and directories.
The MDS client will handle the necessary communication with the MDS servers in the Ceph cluster for metadata operations.

### Unmount CephFS:
To unmount the CephFS, use the umount command followed by the mount point directory. For example:
```bash
sudo umount /path/to/mount/point
```

