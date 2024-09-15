# Monitoring and Alerting with Docker

**Logging Stack:** Loki, Promtail and Grafana

**Web Interface:** Traefik 

## Requirement before running compose file
1. Hardening OS

2. Install docker 

3. Install docker-compose

4. Change and complate config files


## Installation

**Step1**: chnage service config files:
```bash
tree logging
.
|-- README.md
|-- docker-compose.yml
|-- loki
|   `-- local-config.yaml
`-- promtail
    `-- docker-config.yaml

2 directories, 4 files
```

**Step2:** chnage **DOMAIN** on docker-comose file with your domain.

**Step3:** change promtail config

**Step4:** check compose file and Run all services

```bash
docker-compose config
docker-compose up -d
```

**Step5:** Check compose services and view all services logs
```bash
docker-compose ps
docker-compose logs -f --tail 100
```

**Step6:** check and visit your domain service:

1. loki.DOMAIN: loki web interface

2. web.DOMAIN: traefik2 dashboard

3. grafana.DOMAIN: grafana dashboard

**Step7:** config grafana service for view all log on Explore menu

## License
[DockerMe.ir](https://dockerme.ir)