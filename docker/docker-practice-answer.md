# Docker Practice Answer
---

### Step1: install docker
Docker CE for Linux installation script: [get.docker.com](https://get.docker.com/)

```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
```

### Step2: configuration docker

[docker daemon config](change-docker-config.md)

### Step3: create docker network

```bash
# create network
docker network create web_net -o com.docker.network.bridge.name=web_net
docker network create app_net -o com.docker.network.bridge.name=app_net

# check network
docker network ls
```

### Step4: create reverse proxy
[traefik service compose file](traefik-compose.yml)

### Step5: create registry service
[registry service compose file](registry-compose.yml)

### Step6: create elk services
[elk service files](elk)

change `.env` file
```bash
# elk information
ELK_VERSION=7.10.1
ELASTICSEARCH_PASSWORD=DockerMe

# registry information
REGISTRY_URL=repo.docker.mecan.ir
REGISTRY_DIR=elk

# domain name information
DOMAIN_NAME=docker.mecan.ir
ELASTICSEARCH_SUB_DOMAIN=es
KIBANA_SUB_DOMAIN=kibana
```

build and run elk services
```bash
# build image and push to private registry
docker compose build
docker compose push

# run elk service and build it
docker-compose up -d --build
```
### Step7: create wordpress service
[wordpress service compose file](wordpress-compose.yml)

### Step8: create vote service
[voting service files](voting-app)

change `.env` file
```bash
# voting information
VOTE_VERSION=v1.0

# registry information
REGISTRY_URL=repo.docker.mecan.ir
REGISTRY_DIR=vote

# domain name information
DOMAIN_NAME=docker.mecan.ir
RESULT_SUB_DOMAIN=result
VOTE_SUB_DOMAIN=vote
```

build and run vote services
```bash
# build image and push to private registry
docker compose build
docker compose push

# run elk service and build it
docker-compose up -d --build
```

### Step9: create portainer service
[portainer service compose file](portainer-compose.yml)

