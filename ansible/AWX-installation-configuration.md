# Ansible AWX with Docker Install and configuration

### Step 1: Install Ansible
Install ansible with this [link](https://github.com/AhmadRafiee/DevOps_training_with_DockerMe/blob/main/ansible/ansible-installation.md)

### Step 2: Install Docker
Install docker with this commands.

```bash
curl -fsSL https://get.docker.com | bash
```

### Step 3: Install compose and other dependency

```bash
apt update
apt install -y python3-pip
pip3 install docker==6.1.3
pip3 install docker-compose==1.29.2
```

### Step 4: Download Ansible AWX

```bash
[ -d /var/services/ ] || mkdir /var/services/
cd /var/services/
git clone -b 17.1.0 https://github.com/ansible/awx.git
```

### Step 5: Configuration after install Ansible AWX
Generate secret key which you will use later in the inventory and save it
```bash
openssl rand -base64 30
# for example
openssl rand -base64 30
H7Lol8lFwZSgnXAVBk4ybjtC96EGT5tvpOTqkH39
```

Edit and modify variables in awx/installer/inventory
```bash
admin_password=ADMIN_PASSWORD
pg_password=POSTGRES_PASSWORD
secret_key=GENERATE_WITH_OPENSSL_COMMANDS # openssl rand -base64 30
awx_alternate_dns_servers="8.8.8.8,8.8.4.4"
postgres_data_dir="/var/lib/pgdocker"
docker_compose_dir="/var/services/awx/awxcompose"
project_data_dir=/var/lib/awx/projects
```
Create directory for postgres
```bash
[ -d /var/lib/pgdocker ] || mkdir /var/lib/pgdocker
```


#### install docker-compose command line
```bash
curl -SL https://github.com/docker/compose/releases/download/v2.23.3/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
```

### Install AWX
```bash
ansible-playbook -i installer/inventory installer/install.yml -v
```
Example output:
```bash
TASK [local_docker : Update CA trust in awx_web container] **********************************************************************************************************************************************************************************
changed: [localhost] => {"changed": true, "cmd": ["docker", "exec", "awx_web", "/usr/bin/update-ca-trust"], "delta": "0:00:00.454900", "end": "2022-04-27 18:07:02.898039", "rc": 0, "start": "2022-04-27 18:07:02.443139", "stderr": "", "stderr_lines": [], "stdout": "", "stdout_lines": []}

TASK [local_docker : Update CA trust in awx_task container] *********************************************************************************************************************************************************************************
changed: [localhost] => {"changed": true, "cmd": ["docker", "exec", "awx_task", "/usr/bin/update-ca-trust"], "delta": "0:00:00.426620", "end": "2022-04-27 18:07:03.535570", "rc": 0, "start": "2022-04-27 18:07:03.108950", "stderr": "", "stderr_lines": [], "stdout": "", "stdout_lines": []}

TASK [local_docker : Wait for launch script to create user] *********************************************************************************************************************************************************************************
ok: [localhost -> localhost] => {"changed": false, "elapsed": 10, "match_groupdict": {}, "match_groups": [], "path": null, "port": null, "search_regex": null, "state": "started"}

TASK [local_docker : Create Preload data] ***************************************************************************************************************************************************************************************************
changed: [localhost] => {"changed": true, "cmd": ["docker", "exec", "awx_task", "bash", "-c", "/usr/bin/awx-manage create_preload_data"], "delta": "0:00:02.867263", "end": "2022-04-27 18:07:19.284459", "rc": 0, "start": "2022-04-27 18:07:16.417196", "stderr": "", "stderr_lines": [], "stdout": "Default organization added.\nDemo Credential, Inventory, and Job Template added.\n(changed: True)", "stdout_lines": ["Default organization added.", "Demo Credential, Inventory, and Job Template added.", "(changed: True)"]}

PLAY RECAP **********************************************************************************************************************************************************************************************************************************
localhost : ok=21 changed=8 unreachable=0 failed=0 skipped=73 rescued=0 ignored=1
```
Verify if the AWX container is running
```bash
docker ps
CONTAINER ID IMAGE COMMAND CREATED STATUS PORTS NAMES
c0562abc79b8 ansible/awx:17.1.0 "/usr/bin/tini -- /u…" 41 minutes ago Up 2 minutes 8052/tcp awx_task
a6c2c87729a1 ansible/awx:17.1.0 "/usr/bin/tini -- /b…" 42 minutes ago Up 2 minutes 0.0.0.0:80->8052/tcp, :::80->8052/tcp awx_web
3b2982f10b89 postgres:12 "docker-entrypoint.s…" 42 minutes ago Up 2 minutes 5432/tcp awx_postgres
649e05ae34d9 redis "docker-entrypoint.s…" 42 minutes ago Up 2 minutes 6379/tcp awx_redis
[root@centos2 ~]#
```

## Configuration AWX web ssl
install certbot for get certificate
```bash
which certbot || apt install -y certbot
```


Create certificate with certbot command
```bash
docker stop awx_web
DOMAIN=awx.mecan.ir
EMAIL=ahmad@mecan.ir
certbot certonly \
    --standalone \
    --non-interactive \
    --agree-tos \
    --no-eff-email \
    --no-redirect \
    --email ${EMAIL} \
    --domains ${DOMAIN}
```

Add Domain variable on inventory file and certificate path
```bash
DOMAIN=awx.mecan.ir
cat installer/inventory | grep DOMAIN || sed -i '/host_port_ssl=443/a DOMAIN='${DOMAIN}'' installer/inventory
sed -i "s/#ssl_certificate=/ssl_certificate=\/etc\/letsencrypt\/archive\/${DOMAIN}\/fullchain1.pem/g" installer/inventory
sed -i "s/#ssl_certificate_key=/ssl_certificate_key=\/etc\/letsencrypt\/archive\/${DOMAIN}\/privkey1.pem/g" installer/inventory
```

Change server_name on nginx template
```bash
sed -i 's/server_name _;/server_name {{DOMAIN}};/g' installer/roles/local_docker/templates/nginx.conf.j2
```

### Install AWX again
```bash
ansible-playbook -i installer/inventory installer/install.yml -v
```
## Configuration of AWX

To run Ansible Playbook against Linux/Windows machine, we need to configure the following -

**Projects** — it will contain ansible playbook, config, roles, templates etc and will host into a SCM project e.g. github
**Crendentials** — user name/password or ssh key to connect to remote machine
**Inventories** — what servers the playbook will run against and connection specific configuration
**Templates** — Job template to associate all of the above and run the playbook

**These step on awx configuration:**
-  Setup Credentials
-  Setup Inventories
-  Setup Groups
-  Add hosts
-  Setup Projects
-  Create New Job Templates
-  Run the Job Template
-  Run ad-hoc commands on groups
-  Run ad-hoc commands on hosts
-  Add new groups
-  Add new users
-  Change role and limit new user