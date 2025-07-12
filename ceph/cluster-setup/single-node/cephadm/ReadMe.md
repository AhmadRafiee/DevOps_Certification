# Create a Ceph cluster on a single node with `cephadm`

![ceph orchestration](../../../images/ceph-orchestrators.png)

- [Create a Ceph cluster on a single node with `cephadm`](#create-a-ceph-cluster-on-a-single-node-with-cephadm)
  - [Step1: preparing and hardening OS with ansible](#step1-preparing-and-hardening-os-with-ansible)
  - [Step2: Install and config docker service with ansible](#step2-install-and-config-docker-service-with-ansible)
  - [Step3: Add ceph repository and install requirement tools](#step3-add-ceph-repository-and-install-requirement-tools)
  - [Step4: Pull all docker image](#step4-pull-all-docker-image)
  - [Step5: Create ssh-key and create ssh config](#step5-create-ssh-key-and-create-ssh-config)
  - [Step6: Bootstraping cluster with cephadm commands](#step6-bootstraping-cluster-with-cephadm-commands)
  - [Step7: Configuration grafana and set admin password](#step7-configuration-grafana-and-set-admin-password)
  - [Step8: Config ceph service](#step8-config-ceph-service)
  - [Step8: ceph and grafana dashboard access](#step8-ceph-and-grafana-dashboard-access)
  - [Step9: Test the cluster](#step9-test-the-cluster)
  - [Useful commands:](#useful-commands)
  - [Good link:](#good-link)
  - [🔗 Stay connected with DockerMe! 🚀](#-stay-connected-with-dockerme-)


## Step1: preparing and hardening OS with ansible

## Step2: Install and config docker service with ansible

## Step3: Add ceph repository and install requirement tools

To install the release.asc key, execute the following:
```bash
# download from ceph site
wget -q -O- 'https://download.ceph.com/keys/release.asc' | sudo apt-key add -

# download from DockerMe site and use gpg commands
wget -q -O- 'https://store.dockerme.ir/Software/release.asc' | sudo gpg --dearmor -o /usr/share/keyrings/ceph-archive-keyring.gpg
```


You may find releases for Debian/Ubuntu (installed with APT) at:
```
https://download.ceph.com/debian-{release-name}
```
For Octopus and later releases, you can also configure a repository for a specific version x.y.z. For Debian/Ubuntu packages:
```
https://download.ceph.com/debian-{version}
```

Add ceph repository on debian 12
```bash
# add ceph repo [19.2.1]
cat << ROS > /etc/apt/sources.list.d/ceph.list
deb  [arch=amd64 signed-by=/usr/share/keyrings/ceph-archive-keyring.gpg] https://download.ceph.com/debian-19.2.1 bookworm main
ROS

# add ceph repo [18.2.1]
cat << ROS > /etc/apt/sources.list.d/ceph.list
deb  [arch=amd64 signed-by=/usr/share/keyrings/ceph-archive-keyring.gpg] https://download.ceph.com/debian-18.2.1 bookworm main
ROS

# add ceph repo [17.2.7]
cat << ROS > /etc/apt/sources.list.d/ceph.list
deb  [arch=amd64 signed-by=/usr/share/keyrings/ceph-archive-keyring.gpg] https://download.ceph.com/debian-17.2.7 bookworm main
ROS

# add ceph repo [17.2.1]
cat << ROS > /etc/apt/sources.list.d/ceph.list
deb  [arch=amd64 signed-by=/usr/share/keyrings/ceph-archive-keyring.gpg] https://download.ceph.com/debian-17.2.1 bookworm main
ROS

# OR add MeCan repo [19.2.1]
cat << ROS > /etc/apt/sources.list.d/ceph.list
deb  [arch=amd64 signed-by=/usr/share/keyrings/ceph-archive-keyring.gpg] https://repo.mecan.ir/repository/debian-ceph-19.2.1 bookworm main
ROS

# OR add MeCan repo [18.2.1]
cat << ROS > /etc/apt/sources.list.d/ceph.list
deb  [arch=amd64 signed-by=/usr/share/keyrings/ceph-archive-keyring.gpg] https://repo.mecan.ir/repository/debian-ceph-18.2.1 bookworm main
ROS

# OR add MeCan repo [17.2.7]
cat << ROS > /etc/apt/sources.list.d/ceph.list
deb  [arch=amd64 signed-by=/usr/share/keyrings/ceph-archive-keyring.gpg] https://repo.mecan.ir/repository/debian-ceph-17.2.7 bookworm main
ROS

# OR add MeCan repo [17.2.1]
cat << ROS > /etc/apt/sources.list.d/ceph.list
deb  [arch=amd64 signed-by=/usr/share/keyrings/ceph-archive-keyring.gpg] https://repo.mecan.ir/repository/debian-ceph-17.2.1 bookworm main
ROS

# check repo file
cat /etc/apt/sources.list.d/ceph.list
```

Update repository and install requirement packages
```
apt update
apt-cache policy cephadm ceph-common ceph-base
apt install -y cephadm ceph-common ceph-base

# check ceph version
ceph --version
```

## Step4: Pull all docker image
Pull from MeCan registry:
```bash
docker pull quay.mecan.ir/ceph/ceph:v18
docker pull quay.mecan.ir/ceph/ceph:v19
```

Pull from public registry
```bash
docker pull quay.io/ceph/ceph:v18
docker pull quay.io/ceph/ceph:v19
```

## Step5: Create ssh-key and create ssh config

Create ssh-key with this commands:
```
ssh-keygen

# check ssh-key
ls ~/.ssh/
```

add ssh port 22 for cephadm

```bash
cat /etc/ssh/sshd_config | grep Port
sudo sed -i '/^Port/ a Port 22' /etc/ssh/sshd_config
cat /etc/ssh/sshd_config | grep Port

# Test your changes: After modifying the SSH config file, remember to test the configuration with:
sudo sshd -t

# If there are no errors, you can restart the SSH service to apply the changes:
sudo systemctl restart sshd
sudo systemctl status sshd

```

Create ssh config file:

```bash
cat << CTO > ~/.ssh/config
StrictHostKeyChecking no
Host ceph-aio
  Hostname 192.168.200.50
  Port 22
  User root
CTO
```

Add ssh-key to host:
```
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
```

Check ssh to ceph-aio:
```
ssh ceph-aio
```

![ceph network](../../../images/ceph-network.png)

## Step6: Bootstraping cluster with cephadm commands

```bash
cephadm bootstrap --cluster-network 192.168.200.0/24 \
                  --mon-ip 192.168.200.50 \
                  --dashboard-password-noupdate \
                  --initial-dashboard-user admin \
                  --initial-dashboard-password sdwefeoiuijkmwqdcerwaeedwexqwxkqwjnwefe \
                  --allow-fqdn-hostname \
                  --single-host-defaults \
                  --skip-firewalld \
                  --with-centralized-logging
```

after a few minute export this output:
```
Ceph Dashboard is now available at:

	     URL: https://ceph-aio:8443/
	    User: admin
	Password: sdwefeoiuijkmwqdcerwaeedwexqwxkqwjnwefe

Enabling client.admin keyring and conf on hosts with "admin" label
Saving cluster configuration to /var/lib/ceph/4489d864-b135-11ee-b057-fa163eee05b9/config directory
Enabling autotune for osd_memory_target
You can access the Ceph CLI as following in case of multi-cluster or non-default config:

	sudo /usr/sbin/cephadm shell --fsid 4489d864-b135-11ee-b057-fa163eee05b9 -c /etc/ceph/ceph.conf -k /etc/ceph/ceph.client.admin.keyring

Or, if you are only running a single cluster on this host:

	sudo /usr/sbin/cephadm shell

Please consider enabling telemetry to help improve Ceph:

	ceph telemetry on

For more information see:

	https://docs.ceph.com/en/latest/mgr/telemetry/

Bootstrap complete.
```

get docker image with ceph command
```bash
ceph config get mgr mgr/cephadm/container_image_promtail
ceph config get mgr mgr/cephadm/container_image_prometheus
ceph config get mgr mgr/cephadm/container_image_grafana
ceph config get mgr mgr/cephadm/container_image_alertmanager
ceph config get mgr mgr/cephadm/container_image_loki
ceph config get mgr mgr/cephadm/container_image_node_exporter
```

## Step7: Configuration grafana and set admin password

grafana config file path on your host:

    /var/lib/ceph/CLUSTER_ID/grafana.ceph-aio/etc/grafana/grafana.ini

Grafana set admin password:

```bash
# create a file with these configuration
cat <<EOF > grafana.yml
service_type: grafana
spec:
  initial_admin_password: sdfwefweddljlkwmqwoqiwjklsgrw
EOF

# after create file apply to cluster with this commands
ceph orch apply -i grafana.yml

# then redeploy grafana service
ceph orch redeploy grafana
```

## Step8: Config ceph service

usage this command for config all ceph service

```bash
# To print ceph service
ceph orch ls

# To print a list of devices discovered by cephadm, run this command:
ceph orch device ls --wide

# check osd daemon
ceph orch ps --daemon-type osd

# add all devices on osd nodes
ceph orch apply osd --all-available-devices

# check ceph osd daemon
ceph orch ps --daemon-type osd
ceph osd tree

# check ceph cluster state
ceph -s

# view the current placement of the mds daemon
ceph orch ps --daemon-type mds

# MDS service create
ceph fs volume create MeCan_Volumes

# get file system
ceph fs ls

# get file system status
ceph fs status

# view the current placement of the mds daemon
ceph orch ps --daemon-type mds

# get ceph cluster state
ceph -s

# Create a realm
radosgw-admin realm create --rgw-realm=MeCan_realm --default

# Create a zone group
radosgw-admin zonegroup create --rgw-zonegroup=default  --master --default

# Create a zone
radosgw-admin zone create --rgw-zonegroup=default --rgw-zone=test_zone --master --default

# Commit the changes
radosgw-admin period update --rgw-realm=MeCan_realm --commit

# Apply the changes by using the ceph orch apply command.
ceph orch apply rgw MeCan --realm=MeCan_realm --zone=test_zone --zonegroup=default

# get rgw daemon list
ceph orch ps --daemon-type rgw

# view the current placement of the all daemon
ceph orch ps --daemon-type mgr
ceph orch ps --daemon-type rgw
ceph orch ps --daemon-type mds
ceph orch ps --daemon-type mon
ceph orch ps --daemon-type osd
```

## Step8: ceph and grafana dashboard access

To access the Ceph dashboard, you can configure iptables rules to allow access to ports 8443 and 3000. Alternatively, you can set up a reverse proxy using a tool like Nginx to provide access to the dashboards using custom names or URLs.

Sample iptables rules
```
# Allow incoming traffic on port 8443 (Ceph Dashboard)
iptables -A INPUT -p tcp --dport 8443 -j ACCEPT

# Allow incoming traffic on port 3000 (Grafana Dashboard - if applicable)
iptables -A INPUT -p tcp --dport 3000 -j ACCEPT
```

the other way install and config nginx and certbot for access to all panels:
```
apt update
apt install -y nginx certbot python3-certbot-nginx
```

After installation set dns record and get certificate:
Get certificate non interactive with single commands.
```
sudo certbot certonly --nginx --non-interactive --agree-tos -m ahmad@MeCan.ir -d panel.ceph-aio.mecan.ir
sudo certbot certonly --nginx --non-interactive --agree-tos -m ahmad@MeCan.ir -d grafana.ceph-aio.mecan.ir
sudo certbot certonly --nginx --non-interactive --agree-tos -m ahmad@MeCan.ir -d metrics.ceph-aio.mecan.ir
sudo certbot certonly --nginx --non-interactive --agree-tos -m ahmad@MeCan.ir -d alerts.ceph-aio.mecan.ir
```

To create the password file, run the following command:
```
sudo htpasswd -c /etc/nginx/conf.d/.htpasswd MeCan
```

Set nginx config for ceph panel:
```bash
cat > /etc/nginx/conf.d/panel.conf << 'CEO'
server {
    listen 443 ssl;
    server_name panel.ceph-aio.mecan.ir;

    ssl_certificate /etc/letsencrypt/live/panel.ceph-aio.mecan.ir/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/panel.ceph-aio.mecan.ir/privkey.pem;

    # Enable HSTS
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # Enable other security headers
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options SAMEORIGIN;
    add_header X-XSS-Protection "1; mode=block";

    # Set nginx ssl protocol support
    proxy_ssl_protocols TLSv1.2 TLSv1.3;
    proxy_ssl_ciphers DEFAULT;

    location / {
        proxy_pass https://localhost:8443;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    location /api {
        proxy_pass https://localhost:8443/api;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}

server {
    listen 80;
    server_name panel.ceph-aio.mecan.ir;
    # Redirect HTTP to HTTPS
    return 301 https://$host$request_uri;
}
CEO
```

Set nginx config for grafana panel:
```bash
cat > /etc/nginx/conf.d/grafana.conf << 'CEO'
server {
    listen 443 ssl;
    server_name grafana.ceph-aio.mecan.ir;

    ssl_certificate /etc/letsencrypt/live/grafana.ceph-aio.mecan.ir/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/grafana.ceph-aio.mecan.ir/privkey.pem;

    # Enable HSTS
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # Enable other security headers
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options SAMEORIGIN;
    add_header X-XSS-Protection "1; mode=block";

    # Set nginx ssl protocol support
    proxy_ssl_protocols TLSv1.2 TLSv1.3;
    proxy_ssl_ciphers DEFAULT;

    location / {
        proxy_pass https://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}

server {
    listen 80;
    server_name grafana.ceph-aio.mecan.ir;
    # Redirect HTTP to HTTPS
    return 301 https://$host$request_uri;
}
CEO
```

Set nginx config for prometheus panel:
```bash
cat > /etc/nginx/conf.d/metrics.conf << 'CEO'
server {
    listen 443 ssl;
    server_name metrics.ceph-aio.mecan.ir;

    ssl_certificate /etc/letsencrypt/live/metrics.ceph-aio.mecan.ir/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/metrics.ceph-aio.mecan.ir/privkey.pem;

    # Enable HSTS
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # Enable other security headers
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options SAMEORIGIN;
    add_header X-XSS-Protection "1; mode=block";

    # Set nginx ssl protocol support
    proxy_ssl_protocols TLSv1.2 TLSv1.3;
    proxy_ssl_ciphers DEFAULT;

    location / {
        auth_basic "Restricted Content";
        auth_basic_user_file /etc/nginx/conf.d/.htpasswd;
        proxy_pass http://localhost:9095;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}

server {
    listen 80;
    server_name metrics.ceph-aio.mecan.ir;
    # Redirect HTTP to HTTPS
    return 301 https://$host$request_uri;
}
CEO
```


Set nginx config for alertmanager panel:
```bash
cat > /etc/nginx/conf.d/alerts.conf << 'CEO'
server {
    listen 443 ssl;
    server_name alerts.ceph-aio.mecan.ir;

    ssl_certificate /etc/letsencrypt/live/alerts.ceph-aio.mecan.ir/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/alerts.ceph-aio.mecan.ir/privkey.pem;

    # Enable HSTS
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # Enable other security headers
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options SAMEORIGIN;
    add_header X-XSS-Protection "1; mode=block";

    # Set nginx ssl protocol support
    proxy_ssl_protocols TLSv1.2 TLSv1.3;
    proxy_ssl_ciphers DEFAULT;

    location / {
        auth_basic "Restricted Content";
        auth_basic_user_file /etc/nginx/conf.d/.htpasswd;
        proxy_pass http://localhost:9093;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}

server {
    listen 80;
    server_name alerts.ceph-aio.mecan.ir;
    # Redirect HTTP to HTTPS
    return 301 https://$host$request_uri;
}
CEO
```

After configuring all virtual hosts, it is generally safe to remove the default configuration file for Nginx. However, before doing so, it is important to ensure that your Nginx configuration is error-free and valid. You can use the following command to check the Nginx configuration:

```bash
# delete default config
rm /etc/nginx/sites-enabled/default

# check nginx configuration
nginx -t

# restart nginx service
systemctl restart nginx

# enable nginx service
systemctl enable nginx
```

## Step9: Test the cluster
The block storage provided by Ceph is named RBD, which stands for RADOS block device.

To create disks, you need a pool enabled to work with RBD. The commands below create a pool called rbd and then activate this pool for RBD:

    sudo ceph osd pool create rbd

    sudo ceph osd pool application enable rbd rbd

After that, you can use the rbd command line to create and list available disks:

    sudo rbd create mysql --size 1G
    sudo rbd create mongodb --size 2G

Check rbd images:

    sudo rbd list

The output will be:

    mongodb
    mysql

## Useful commands:

    ceph osd ls
    ceph osd tree
    ceph orch ls
    ceph mgr module ls
    ceph orch ps
    ceph orch apply osd --all-available-devices

Delete and purge osd with id:

    ceph osd out ID
    ceph osd safe-to-destroy osd.ID
    ceph osd destroy ID --yes-i-really-mean-it
    ceph osd purge ID --yes-i-really-mean-it


Check and zap device with this command:

    ceph orch device ls
    ceph orch device zap ceph-aio /dev/vdc --force

Image list:

    quay.io/ceph/ceph:v18
    quay.io/ceph/ceph-grafana:9.4.7
    quay.io/prometheus/prometheus:v2.43.0
    quay.io/prometheus/alertmanager:v0.25.0
    quay.io/prometheus/node-exporter:v1.5.0
    grafana/loki:2.4.0
    grafana/promtail:2.4.0

You can stop, start, or restart a daemon with:

    ceph orch daemon stop <name>
    ceph orch daemon start <name>
    ceph orch daemon restart <name>

The container for a daemon can be stopped, recreated, and restarted with the redeploy command:

    ceph orch daemon redeploy <name> [--image <image>]


## Good link:
  - https://www.redhat.com/sysadmin/ceph-cluster-single-machine
  - https://docs.ceph.com/en/latest/cephadm/services/monitoring/
  - https://www.ibm.com/docs/en/storage-ceph/5?topic=access-setting-admin-user-password-grafana

## 🔗 Stay connected with DockerMe! 🚀

**Subscribe to our channels, leave a comment, and drop a like to support our content. Your engagement helps us create more valuable DevOps and cloud content!** 🙌

[![Site](https://img.shields.io/badge/Dockerme.ir-0A66C2?style=for-the-badge&logo=docker&logoColor=white)](https://dockerme.ir/) [![linkedin](https://img.shields.io/badge/linkedin-0A66C2?style=for-the-badge&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/ahmad-rafiee/) [![Telegram](https://img.shields.io/badge/telegram-0A66C2?style=for-the-badge&logo=telegram&logoColor=white)](https://t.me/dockerme) [![YouTube](https://img.shields.io/badge/youtube-FF0000?style=for-the-badge&logo=youtube&logoColor=white)](https://youtube.com/@dockerme) [![Instagram](https://img.shields.io/badge/instagram-FF0000?style=for-the-badge&logo=instagram&logoColor=white)](https://instagram.com/dockerme)
