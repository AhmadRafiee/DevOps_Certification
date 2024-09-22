# Install and configuraion docker

### Install requirements basic tools:

```bash
apt install -y wget git vim bash-completion curl htop net-tools dnsutils \
               atop sudo software-properties-common telnet axel jq iotop \
               ca-certificates curl gnupg lsb-release apt-transport-https gpg
```

##### get gpg key and add docker repositroy:

Add Docker’s official GPG key:
```bash
sudo mkdir -p /etc/apt/keyrings && sudo chmod -R 0755 /etc/apt/keyrings
curl -fsSL "https://download.docker.com/linux/debian/gpg" | gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
```

OR Download docker.gpg from mecan repository
```bash
curl -fsSL "https://repo.mecan.ir/repository/debian-docker/gpg" | gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
```

**NOTE:** if your servers are in Iran too, you should do this with an HTTP proxy; otherwise, you will get a 403 error.
```bash
chmod a+r /etc/apt/keyrings/docker.gpg
```

Use the following command to set up the repository:
```bash
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian bullseye stable" > /etc/apt/sources.list.d/docker.list
cat /etc/apt/sources.list.d/docker.list
```

If apt mirror repository, add this line instead. We are using mirror repository `repo.mecan.ir`
```bash
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://repo.mecan.ir/repository/debian-docker bookworm stable" > /etc/apt/sources.list.d/docker.list
cat /etc/apt/sources.list.d/docker.list
```

Update cache repository and install containerd:
```bash
sudo apt-get update
```

### Install Docker
```bash
apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin docker-buildx-plugin docker-ce-rootless-extras docker-scan-plugin
```

### Configuration docker
```bash
# check docker config directory

[[ -d /etc/docker ]] || mkdir /etc/docker

cat <<EOF > /etc/docker/daemon.json

{
    "registry-mirrors": ["https://hub.mecan.ir","https://hub.hamdocker.ir"]
}
EOF

# restart docker service
systemctl restart docker
systemctl enable docker
systemctl status docker
```

### To create the docker group and add your user:

Create the docker group.
```bash
sudo groupadd docker
```

Add your user to the docker group.
```bash
sudo usermod -aG docker $USER
```
Log out and log back in so that your group membership is re-evaluated.


### Proxy configuration on docker daemon
**Daemon configuration**
You may configure proxy behavior for the daemon in the daemon.json file, or using CLI flags for the `--http-proxy` or `--https-proxy` flags for the dockerd command. Configuration using daemon.json is recommended.

```bash
{
  "proxies": {
    "http-proxy": "http://proxy.example.com:3128",
    "https-proxy": "http://proxy.example.com:3129",
    "no-proxy": "*.test.example.com,.example.org,127.0.0.0/8"
  }
}
```
After changing the configuration file, restart the daemon for the proxy configuration to take effect:

```bash
sudo systemctl restart docker
```

**systemd unit file**
If you're running the Docker daemon as a systemd service, you can create a systemd drop-in file that sets the variables for the docker service.

```bash
[Service]
Environment="HTTP_PROXY=http://proxy.example.com:3128"
Environment="HTTPS_PROXY=http://proxy.example.com:3129"
Environment="NO_PROXY=localhost,127.0.0.1,docker-registry.example.com,.corp"
```

Flush changes and restart Docker

```bash
sudo systemctl daemon-reload
sudo systemctl restart docker
```

**Verify that the configuration has been loaded and matches the changes you made, for example:**
```bash
sudo systemctl show --property=Environment docker
```