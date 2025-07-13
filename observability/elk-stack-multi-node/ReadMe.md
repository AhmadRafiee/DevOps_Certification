# ELK Stack deploy multi nodes

- [ELK Stack deploy multi nodes](#elk-stack-deploy-multi-nodes)
  - [Overview](#overview)
  - [Prerequisites](#prerequisites)
  - [Project Structure](#project-structure)
  - [Configuration](#configuration)
  - [Secrets](#secrets)
  - [Configs](#configs)
  - [Deployment](#deployment)
  - [Accessing the Services](#accessing-the-services)
  - [Health Checks](#health-checks)
  - [Troubleshooting](#troubleshooting)
  - [Stay connected with DockerMe! 🚀](#stay-connected-with-dockerme-)

## Overview
This Docker Compose setup creates a robust and scalable ELK stack for centralized logging, monitoring, and analysis. It leverages the following components:

* **Elasticsearch:** A distributed search and analytics engine. This setup includes three nodes (elasticsearch-node-1, elasticsearch-node-2, elasticsearch-node-3) for high availability and data redundancy.
* **Logstash:** A server-side data processing pipeline that ingests data from multiple sources simultaneously, transforms it, and then sends it to a "stash" like Elasticsearch. This setup includes three nodes (logstash-node-1, logstash-node-2, logstash-node-3).
* **Kibana:** A web interface for searching, analyzing, and visualizing data stored in Elasticsearch. This setup includes three nodes (kibana-node-1, kibana-node-2, kibana-node-3) exposed via Traefik.
* **Fleet Server:** A component of Elastic Agent that centralizes the management of Elastic Agents. This setup includes three nodes (fleet-node-1, fleet-node-2, fleet-node-3) exposed via Traefik.
* **Traefik:** Used as a reverse proxy and load balancer to expose Kibana and Fleet Server securely with automatic HTTPS (using mycert resolver, likely Let's Encrypt).
* **Docker Networks:**
  * **web_net:** External network for Traefik and services exposed to the web.
  * **app_net:** Internal network for communication between ELK stack components.
* **Docker Volumes:** Persistent volumes (es1_data, es2_data, es3_data) are used for Elasticsearch data to ensure data persistence across container restarts.
* **Docker Secrets:** Sensitive information like certificates, keys, and service tokens are managed using Docker secrets for enhanced security.
* **Docker Configs:** Configuration files for Elasticsearch, Logstash, and Kibana are managed as Docker configs.

## Prerequisites
Before deploying this ELK cluster, ensure you have the following installed:

* **Docker Engine:** Version 20.10.0 or higher.
* **Docker Compose:** Version 1.29.0 or higher (or Docker Compose V2).
* **Traefik:** An existing Traefik instance configured with web_net as an external network and a certificate resolver (e.g., mycert) is assumed for external access.
* **SSL Certificates:** Ensure you have generated or obtained the necessary TLS certificates and keys for Elasticsearch, Kibana, Fleet Server, and a CA certificate. These should be placed in the secrets/certs directory as specified in the docker-compose.yml.
* **Elasticsearch Keystore:** An Elasticsearch keystore should be pre-created if needed for secure settings.
* **Elasticsearch Service Tokens:** Service tokens for Elasticsearch should be available.
* **Logstash Pipeline Configuration:** Logstash pipelines should be defined in the ./logstash/pipeline directory.

## Project Structure
The project expects the following directory structure:
```bash
├── docker-compose.yml
├── elasticsearch
│   ├── elasticsearch.yml
│   └── log4j2.properties
├── kibana
│   └── kibana.yml
├── logstash
│   ├── config
│   │   ├── logstash.yml
│   │   └── pipelines.yml
│   └── pipeline
│       └── main.conf
├── ReadMe.md
├── setup
│   ├── instances.yml
│   ├── keystore.sh
│   ├── setup-certs.sh
│   └── setup-keystore.sh
└── setup-certs-compose.yml
```

## Configuration
`.env` file
The `.env` file contains environment variables crucial for the ELK stack's operation. Before deployment, you must configure this file:

```bash
#----------- Service Domain Config ---------------#
DOMAIN_NAME=monlog.mecan.ir
ES1_SUB_DOMAIN=es1
ES2_SUB_DOMAIN=es2
ES3_SUB_DOMAIN=es3
KIBANA1_SUB_DOMAIN=kibana1
KIBANA2_SUB_DOMAIN=kibana2
KIBANA3_SUB_DOMAIN=kibana3
FLEET1_SUB_DOMAIN=fleet
FLEET2_SUB_DOMAIN=fleet2
FLEET3_SUB_DOMAIN=fleet3

LB_KIBANA_SUB_DOMAIN=kibana
LB_FLEET_SUB_DOMAIN=fleet
LB_ES_SUB_DOMAIN=es

# ELK Stack Version
ELK_VERSION=8.11.3

# Resources
ELASTICSEARCH_HEAP=1024m
LOGSTASH_HEAP=512m

# URL and Ports
ELASTICSEARCH_CLUSTER_HOSTS=["https://elasticsearch-node-1:9200","https://elasticsearch-node-2:9200","https://elasticsearch-node-3:9200"]
ELASTICSEARCH_PORT=9200

KIBANA_HOST=kibana
KIBANA_PORT=5601
KIBANA_PUBLIC_URL=https://${KIBANA1_SUB_DOMAIN}.${DOMAIN_NAME}

LOGSTASH_HOST=logstash
LOGSTASH_PORT=8080

APMSERVER_HOST=apm-server
APMSERVER_PORT=8200

# ELK Stack Credientals
# Username & Password for Admin Elasticsearch cluster.
# This is used to set the password at setup, and used by others to connect to Elasticsearch at runtime.
# USERNAME cannot be changed! It is set here for parmeterization only.
ELASTIC_USERNAME=elastic
ELASTIC_PASSWORD=CBNJycqAJcB9cPdwbSA5MZdME4Laen
ELASTIC_APM_SECRET_TOKEN=QY4A2GaXPEcJNAZbNyjf7ZrjMTBj4yQY4A2GaXPEcJNA
FLEET_SERVER_SERVICE_TOKEN=AAEAAWVsYXN0aWMvZmxlZXQtc2VydmVyL3Rva2VuLTE3MDM4ODgyOTM0NTk6Zlk3bE4xRmxSd3FuZ0FxWkJlWG5CQQ

# Elasticsearch Cluster Variables
ELASTIC_CLUSTER_NAME=elk-cluster
ELASTIC_INIT_MASTER_NODE=elasticsearch-node-1
ELASTIC_NODE_NAME_1=elasticsearch-node-1
ELASTIC_NODE_NAME_2=elasticsearch-node-2
ELASTIC_NODE_NAME_3=elasticsearch-node-3

# Hostnames of master eligble elasticsearch instances. (matches compose generated host name)
ELASTIC_DISCOVERY_SEEDS=elasticsearch-node-1,elasticsearch-node-2,elasticsearch-node-3

# Set Restart Policy config
RESTART_POLICY=unless-stopped
```

**Key variables to review and update:**

* **`DOMAIN_NAME:`** Your primary domain name for services.
* **`ELK_VERSION:`** The desired version of Elasticsearch, Logstash, and Kibana.
* **`ELASTICSEARCH_HEAP:`** Allocated heap size for Elasticsearch nodes (e.g., 4g). Adjust this based on your server's available RAM.
* **`LOGSTASH_HEAP:`** Allocated heap size for Logstash nodes (e.g., 2g). Adjust this based on your server's available RAM.
* **`ELASTIC_PASSWORD:`** Crucially, change this to a strong, secure password. This is the superuser password for your Elasticsearch cluster.
* **`ELASTIC_APM_SECRET_TOKEN:`** A secret token for APM server. Generate a strong, random token.
* **`FLEET_SERVER_SERVICE_TOKEN:`** A service token for Fleet Server. Generate a strong, random token.
* **`KIBANA_PUBLIC_URL:`** The public URL for Kibana, should match one of your Kibana subdomains.
* **`RESTART_POLICY:`** Defines the container restart behavior. unless-stopped is generally recommended for production.

## Secrets
Ensure all required secret files are present in the `secrets/` directory as described in the "Project Structure" section. These include:

* **TLS Certificates and Keys:** For securing communication between components and external access via Traefik.
* **`ca.crt`** (Root CA certificate)
  * **`elasticsearch.crt`, `elasticsearch.key`**
  * **`kibana.crt`, `kibana.key`**
  * **`fleet.crt`, `fleet.key`**
  * **`apm-server.crt`, `apm-server.key`** (Though APM server service is not defined, its secrets are here).
* **`elasticsearch.keystore`:** Contains secure settings for Elasticsearch.
* **`elasticsearch.service_tokens`:** Contains service tokens for Elasticsearch.
* **`.env.kibana.token`:** An environment file for Kibana-specific tokens (if any).

## Configs
Configuration files are mounted as Docker configs:

* **`./elasticsearch/elasticsearch.yml`:** Elasticsearch configuration.
* **`./elasticsearch/log4j2.properties`:** Elasticsearch logging configuration.
* **`./logstash/config/logstash.yml`:** Logstash configuration.
* **`./logstash/config/pipelines.yml`:** Defines Logstash pipelines.
* **`./kibana/kibana.yml`:** Kibana configuration.

**Important:** Review and customize these configuration files according to your specific needs (e.g., memory allocation, network settings, pipeline definitions, security settings).

## Deployment
* Clone the repository (if applicable) or create the project structure.
* Certificate create from this file and change it with your name and variables
```bash
instances:
  - name: elasticsearch
    dns:
      - elasticsearch-node-1
      - elasticsearch-node-2
      - elasticsearch-node-3
      - es.monlog.mecan.ir
      - es1.monlog.mecan.ir
      - es2.monlog.mecan.ir
      - es3.monlog.mecan.ir
      - localhost
    ip:
      - 127.0.0.1

  - name: kibana
    dns:
      - kibana-node-1
      - kibana-node-2
      - kibana-node-3
      - localhost
      - kibana.monlog.mecan.ir
      - kibana1.monlog.mecan.ir
      - kibana2.monlog.mecan.ir
      - kibana3.monlog.mecan.ir
    ip:
      - 127.0.0.1

  - name: logstash
    dns:
      - logstash-node-1
      - logstash-node-2
      - logstash-node-3
      - localhost
    ip:
      - 127.0.0.1

  - name: apm-server
    dns:
      - apm-server
      - localhost
    ip:
      - 127.0.0.1

  - name: fleet
    dns:
      - fleet-node-1
      - fleet-node-2
      - fleet-node-3
      - localhost
      - fleet.monlog.mecan.ir
      - fleet1.monlog.mecan.ir
      - fleet2.monlog.mecan.ir
      - fleet3.monlog.mecan.ir
    ip:
      - 127.0.0.1
```
* Populate the `secrets/` directory with your TLS certificates, keys, keystore, and service tokens. with this commands
```bash
# before create certificate check this file 
# change domain for this file
cat setup/instances.yml 

# create certificates
docker compose -f setup-certs-compose.yml up

# after create certificates delete pods
docker compose -f setup-certs-compose.yml down

# check all certificate 
ls secrets

# check certificate with this command
openssl x509  -text -noout -in secrets/certs/elasticsearch/elasticsearch.crt
```
* Create and configure the `.env` file as described above.
* Review and customize the configuration files in `elasticsearch/`, `logstash/`, and `kibana/`.
* Ensure your Traefik instance is running and configured with the `web_net` and a certificate resolver (e.g., mycert).
* From the root directory of this project, deploy the stack using Docker Compose:

```Bash
# run all services
docker compose up -d

# check all containers
docker compose ps
```
**This command will:**
* Create the defined volumes and networks.
* Build (if necessary) and start all services.
* Attach secrets and configs to the respective containers.

## Accessing the Services
Once the services are up and healthy, you can access them via the Traefik-exposed domains:

* **Kibana:** Access Kibana through the subdomain configured in `KIBANA1_SUB_DOMAIN` (e.g., `https://kibana1.monlog.mecan.ir`). You'll be prompted to log in using the `ELASTIC_USERNAME` and `ELASTIC_PASSWORD` from your `.env` file.
* **Elasticsearch:** Elasticsearch nodes are exposed via their subdomains (e.g., `https://es1.monlog.mecan.ir`). You can interact with them using tools like curl or client libraries, providing the `ELASTIC_USERNAME` and `ELASTIC_PASSWORD`.
* **Fleet Server:** Access Fleet Server through the subdomain configured in `FLEET1_SUB_DOMAIN` (e.g.,` https://fleet.monlog.mecan.ir`).

## Health Checks
Each service includes a `healthcheck` definition in the `compose.yml` to ensure proper functioning. You can monitor the health of your services using:

```Bash
docker compose ps
docker compose ps -a
```
Look for the "health" column in the output.

## Troubleshooting
* **Check Docker Logs:** The first step in troubleshooting is to check the logs of the problematic service:

```Bash
docker compose logs <service_name>

# For example: 
docker compose logs elasticsearch-node-1
```
* **Verify `.env` and Config Files:** Double-check that all environment variables in `.env` are correctly set and that your configuration files (.yml, .properties) are properly formatted and contain the correct settings.
* **Network Issues:** Ensure the web_net and app_net are correctly configured and that containers can communicate as expected.
* **Certificate Errors:** If you encounter TLS/SSL errors, verify that your certificates and keys are correctly placed and have the right permissions, and that the paths in `compose.yml` are accurate.
* **Memory Issues:** If containers are crashing or restarting frequently, consider increasing the `ELASTICSEARCH_HEAP` and `LOGSTASH_HEAP` values in your .env file, provided your host has sufficient RAM.
* **Traefik Configuration:** Confirm that your Traefik instance is running and its configuration correctly routes traffic to the ELK services.

## Stay connected with DockerMe! 🚀

**Subscribe to our channels, leave a comment, and drop a like to support our content. Your engagement helps us create more valuable DevOps and cloud content!** 🙌

[![Site](https://img.shields.io/badge/Dockerme.ir-0A66C2?style=for-the-badge&logo=docker&logoColor=white)](https://dockerme.ir/) [![linkedin](https://img.shields.io/badge/linkedin-0A66C2?style=for-the-badge&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/ahmad-rafiee/) [![Telegram](https://img.shields.io/badge/telegram-0A66C2?style=for-the-badge&logo=telegram&logoColor=white)](https://t.me/dockerme) [![YouTube](https://img.shields.io/badge/youtube-FF0000?style=for-the-badge&logo=youtube&logoColor=white)](https://youtube.com/@dockerme) [![Instagram](https://img.shields.io/badge/instagram-FF0000?style=for-the-badge&logo=instagram&logoColor=white)](https://instagram.com/dockerme)
