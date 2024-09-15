# Monitoring and Alerting with Docker

**Monitoring Stack:** Prometheus, Exporters and Grafana

**Alerting:** Alertmanager

**Web Interface:** Traefik 

## Requirement before running compose file
1. Hardening OS

2. Install docker 

3. Install docker-compose

4. Change and complate config files


## Installation

**Step1**: chnage service config files:
```bash
tree monitoring
.
|-- README.md
|-- alertmanager
|   `-- config.yml
|-- docker-compose.yml
|-- grafana-dashboard
|   |-- docker-monitoring_rev1.json
|   `-- node-exporter-full_rev16.json
`-- prometheus
    |-- alerts
    |   |-- Alertmanager.rules
    |   `-- Prometheus.rules
    `-- prometheus.yml

4 directories, 8 files
```

**Step2:** chnage **DOMAIN** on docker-comose file with your domain.

**Step3:** change alertmanager email notification config

**Step4:**check compose file and Run all services
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

1. prometheus.DOMAIN: prometheus dashboard

2. web.DOMAIN: traefik2 dashboard

3. alert.DOMAIN: alertmanager dashboard

4. grafana.DOMAIN: grafana dashboard

**Step7:** config grafana service for view all metric on visualize dashboard

## License
[DockerMe.ir](https://dockerme.ir)