#!/bin/bash
set -e

# remove default repository
sudo rm /etc/apt/sources.list.d/debian.sources

# add MeCan repository
sudo tee /etc/apt/sources.list.d/MeCan.list > /dev/null <<'EOF'
deb https://repo.mecan.ir/repository/debian/ bookworm main
deb https://repo.mecan.ir/repository/debian/ bookworm-updates main
deb https://repo.mecan.ir/repository/debian/ bookworm-backports main
deb https://repo.mecan.ir/repository/debian-security/ bookworm-security main
EOF

# update and upgrade debian os
sudo apt-get clean
sudo apt-get update
sudo apt-get upgrade -y

# install tools 
sudo apt-get install -y gpg git

# add docker repository
curl -fsSL https://repo.mecan.ir/repository/debian-docker/gpg | sudo gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
echo 'deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://repo.mecan.ir/repository/debian-docker bookworm stable' | sudo tee /etc/apt/sources.list.d/docker.list

# update cache and install docker tools
sudo apt-get update
sudo apt-get install -y containerd.io docker-ce docker-buildx-plugin docker-ce-cli docker-ce-rootless-extras docker-compose-plugin docker-scan-plugin

# post install and config docker
sudo usermod -aG docker $USER
[ -d /etc/docker ] || mkdir /etc/docker

sudo tee /etc/docker/daemon.json > /dev/null <<'EOF'
{
    "log-opts": {
        "labels": "mecan_instance",
        "max-file": "5",
        "max-size": "100M"
    },
    "registry-mirrors": ["https://hub.mecan.ir","https://docker.arvancloud.ir","https://hub.hamdocker.ir"],
    "experimental": true,
    "live-restore": true
}
EOF
sudo systemctl restart docker

# Clean cloud-init for fresh instance bo
sudo rm -rf /var/lib/cloud/* 