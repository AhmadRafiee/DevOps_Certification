# OpenStack Smoke Tests

Here’s a comprehensive list of smoke tests to verify various OpenStack functionalities. These tests cover different services and interactions within an OpenStack environment.

Before run smoke tests source `/etc/kolla/admin-openrc.sh`
```bash
source /etc/kolla/admin-openrc.sh
```

**Service Verification:** Check OpenStack services status

```bash
openstack service list
```

**Check Nova (Compute) services:**

```bash
openstack compute service list
```

**Check Neutron (Network) services:**

```bash
openstack network agent list
```

**Check Glance (Image) services:**

```bash
openstack image list
```

**Check Keystone (Identity) services:**
```bash
openstack endpoint list
```

**Check Cinder (Block Storage) services:**
```bash
openstack volume list
```

**Check Swift (Object Storage) services:**
```bash
openstack container list
openstack container create test
openstack object list test
openstack container delete test
```

**Check Horizon (Dashboard) access:** Open your browser and navigate to the Horizon dashboard URL.

**Project and User Management**

**Create a new project:**
```bash
openstack project create test-project
```

**Create a new user:**
```bash
openstack user create --project test-project --password-prompt test-user
```

**Assign a role to the user:**
```bash
openstack role add --project test-project --user test-user member
```

**List users in the project:**
```bash
openstack user list --project test-project
```

**Delete the test user:**
```bash
openstack user delete test-user
```

**Delete the test project:**
```bash
openstack project delete test-project
```

**Image Management**
**Create a new image:**
```bash
wget http://download.cirros-cloud.net/0.6.3/cirros-0.6.3-aarch64-disk.img
openstack image create --file cirros-0.6.3-aarch64-disk.img --disk-format qcow2 --private test-image
```

**List all images:**
```bash
openstack image list
```

**Show image details:**
```bash
openstack image show test-image
```

**Delete the test image:**
```bash
openstack image delete test-image
```

**Network Management**
**Create a new network:**
```bash
openstack network create test-network
```

**List all networks:**
```bash
openstack network list
```

**Create a subnet:**
```bash
openstack subnet create --network test-network --subnet-range 192.168.1.0/24 test-subnet
```

**List all subnets:**
```bash
openstack subnet list
```

**Create a router:**
```bash
openstack router create test-router
```

**Set external gateway for the router:**
```bash
openstack router set --external-gateway public test-router
```

**Add subnet to the router:**
```bash
openstack router add subnet test-router test-subnet
```

**Show router details:**
```bash
openstack router show test-router
```

**Delete the test router:**
```bash
openstack router delete test-router
```

**Delete the test network:**
```bash
openstack network delete test-network
```

**Security and Access Management**
**Create a security group:**
```bash
openstack security group create test-security-group
```

**Add an SSH rule to the security group:**
```bash
openstack security group rule create --protocol tcp --dst-port 22 test-security-group
```

**List security groups:**
```bash
openstack security group list
```

**Delete the security group:**
```bash
openstack security group delete test-security-group
```

**Keypair Management**
**Create a keypair:**
```bash
openstack keypair create --public-key <path-to-public-key> test-key
```

**List keypairs:**
```bash
openstack keypair list
```

**Delete the keypair:**
```bash
openstack keypair delete test-key
```

**Instance Management**

**create flavor**
```bash
openstack flavor create --ram 2048 --disk 20 --vcpus 1 --public m1.small
```

**Launch a test instance:**
```bash
openstack server create --flavor m1.small --image test-image --network test-network --key-name test-key test-instance
```

**List all instances:**
```bash
openstack server list
```

**Show instance details:**
```bash
openstack server show test-instance
```

**Access the instance via SSH:**
```bash
ssh -i <path-to-private-key> <username>@<instance-ip>
```

**Reboot the instance:**
```bash
openstack server reboot test-instance
```

**Stop the instance:**
```bash
openstack server stop test-instance
```

**Start the instance:**
```bash
openstack server start test-instance
```

**Delete the test instance:**
```bash
openstack server delete test-instance
```

**Volume Management (Cinder)**
**Create a new volume:**
```bash
openstack volume create --size 1 test-volume
```

**List all volumes:**
```bash
openstack volume list
```

**Attach a volume to an instance:**
```bash
openstack server add volume test-instance test-volume
```

**Detach the volume from the instance:**
```bash
openstack server remove volume test-instance test-volume
```

**Delete the test volume:**
```bash
openstack volume delete test-volume
```

**Final Cleanup**
**Delete the test subnet:**
```bash
openstack subnet delete test-subnet
```

**Delete any remaining networks, images, or resources to clean up:**  Ensure the environment is clean to prepare for future tests.