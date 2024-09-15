# Docker plugin - logging 
## Plugin Installation​
```bash
# install plugin
docker plugin install  grafana/loki-docker-driver:latest --alias loki --grant-all-permissions​

# check
docker plugin ls​
```

## Configure the default logging driver​
```bash
# check daemon logging before configuration
docker info | grep "Logging Driver"

# configure
vim /etc/systemd/system/docker.service.d/override.conf
[Service]​
ExecStart=​
ExecStart=/usr/bin/dockerd --log-driver loki --log-opt loki-url="https://<user_id>:<password>@<loki_address>/api/prom/push" --log-opt loki-batch-size=400 ​

# reload systemd and restart docker 
systemctl daemon-reload
systemctl restart docker
systemctl status docker

# check daemon logging after configuration
docker info | grep "Logging Driver"
```
## Configure the logging driver for a container​
```bash
docker run --log-driver=loki \​
    --log-opt loki-url="https://<user_id>:<password>@<loki_address>/api/prom/push" \​
    --log-opt loki-batch-size=400 \​
    grafana/grafana​
```