# Prometheus Stack

## Prometheus Stack Design
![Prometheus Stack](photo/Prometheus-Stack.png "Prometheus-Stack")

### A Prometheus & Grafana docker compose stack

Here's a quick start using Compose file to start-up a [Prometheus](http://prometheus.io/) stack containing Prometheus, Grafana and Node scraper to monitor your Docker infrastructure.

### Project structure:
```bash
prometheus-stack
├── alertmanager
│   └── alertmanager.yml
├── blackbox
│   └── blackbox-exporter.yml
├── compose.yml
├── grafana
│   ├── dashboards
│   │   ├── BlackboxPingTest.json
│   │   ├── BlackboxWebTest.json
│   │   ├── dashboard.yml
│   │   ├── DockerContainerMonitor.json
│   │   ├── GrafanaMetrics.json
│   │   ├── NodeExporterFull.json
│   │   ├── Prometheus2.0Stats.json
│   │   └── Traefik2Dashboard.json
│   └── datasources
│       └── datasource.yml
├── photo
│   └── Prometheus-Stack.png
├── prometheus
│   ├── alerts
│   │   ├── Alertmanager.rules
│   │   ├── BlackBox.rules
│   │   ├── Cadvisor.rules
│   │   ├── Node_Exporter.rules
│   │   ├── Prometheus.rules
│   │   └── Traefik.rules
│   └── prometheus.yml
└── ReadMe.md
```

### Change environment variables:
```bash
cat .env
# Domain address
DOMAIN_ADDRESS=observability.mecan.ir
PROSUB=metrics
GRASUB=grafana
ALESUB=alerts
PGWSUB=pushgw

# Grafana Auth
GRAFANA_USERNAME=MeCan
GRAFANA_PASSWORD=<GRAFANA_ADMIN_PASSWORD>
GRAFANA_INSTALL_PLUGINS=grafana-clock-panel,grafana-simple-json-datasource,grafana-piechart-panel

# Server Name
HOSTNAME=observability

# set restart policy
RESTART_POLICY=on-failure
```

### Containers Defination:

- Prometheus (metrics database)
- Prometheus-Pushgateway (push acceptor for ephemeral and batch jobs)
- AlertManager (alerts management)
- Grafana (visualize metrics)
- NodeExporter (host metrics collector)
- cAdvisor (containers metrics collector)
- blackbox-exporter (The blackbox exporter allows blackbox probing of endpoints over HTTP, HTTPS, DNS, TCP, ICMP and gRPC.)

### Setup Grafana
Navigate to http://<host-ip>:3000 and login with user admin password admin. You can change the credentials in the compose file or by supplying the `GRAFANA_USERNAME`, `GRAFANA_PASSWORD`, and `GRAFANA_INSTALL_PLUGINS` environment variables via .env file on compose up.

Grafana is provisioning dashboards abd data source with this configs:
```bash
cat grafana/datasources.yml
apiVersion: 1
datasources:
- name: Prometheus
  type: prometheus
  access: proxy
  url: http://prometheus:9090
  editable: true
  isDefault: true
```
```bash
cat grafana/dashboard.yml
apiVersion: 1
providers:
- name: 'Prometheus'
  orgId: 1
  folder: 'MeCan_Services'
  type: file
  disableDeletion: false
  editable: true
  options:
    path: /etc/grafana/provisioning/dashboards
```

### Alerting
Alerting has been added to the stack with Slack integration.

All rules in `prometheus/alerts` directory.

Notification media config for Telegram and Email receivers in  `alertmanager/alertmanager.yml`


### Deploy with docker compose:
```bash
# check compose file syntax
docker compose config

# pull all images in compose file
docker compose pull

# run all containers in compose file
docker compose up -d
```

## How to configure Prometheus Alertmanager to send alerts to Telegram
**Step One** => Get a telegram bot

Create telegram bot via `@botfather` [link](https://core.telegram.org/bots#6-botfather)

**Step Two** => Create a channel and invite the bot to the channel

The bot must be invited as admin.

**Step Three** => Find the chat ID

after the bot is in the channel, type a message in the channel, then go to:

    https://api.telegram.org/botYOUR_BOT_TOKEN/getUpdates

Please note: the chat ID might start with a - sign. It’s part of the ID (it’s actually a negative integer) and you need to copy that too.

If the page is empty, type another message in the channel and try again.

Take note of the chat ID, we’ll need it later.

**Step Four** => Configure alertmanager

The official configuration documentation is on this [link](https://prometheus.io/docs/alerting/latest/configuration)

For my tests, I added these 2 snippets.

```bash
route:
  - match:
      severity: test-telegram
    receiver: stardata-telegram

receivers:
- name: 'stardata-telegram'
  telegram_configs:
  - bot_token: YOUR_BOT_TOKEN
    api_url: https://api.telegram.org
    chat_id: YOUR_CHAT_ID
    parse_mode: ''
```
If you need a proxy, add the http_config section below:

```bash
receivers:

- name: 'stardata-telegram'
  telegram_configs:
  - bot_token: YOUR_BOT_TOKEN
    api_url: https://api.telegram.org
    chat_id: YOUR_CHAT_ID
    parse_mode: ''
    http_config:
      proxy_url: 'http://your-proxy-server-if-required:3128'
```

**Step Five** => Test the configuration

To create a temporary alert to test the configuration, run

```bash
amtool --alertmanager.url=http://localhost:9093/ alert add alertname="test123" severity="test-telegram" job="test-alert" instance="localhost" exporter="none" cluster="test"
```


**Step Six** => Important Notes

- You probably have your chat ID in the config between quotes, it should go without quotes.
- I had to enable api.telegram.org on my proxy server whitelist.
- This telegram [bot](https://t.me/username_to_id_bot) to get user, group and channel ids.
- AlertManager telegram config [refrence](https://prometheus.io/docs/alerting/latest/configuration/#telegram_config)

### Ref:
Good Link: https://velenux.wordpress.com/2022/09/12/how-to-configure-prometheus-alertmanager-to-send-alerts-to-telegram/
