# Introduction
Elastic Stack (**ELK**) Docker Composition, preconfigured with **Security**, **Monitoring**, and **Tools**; Up with a Single Command.

Stack Version: [7.17.13](https://www.elastic.co/blog/elastic-stack-7-17-13-released)

> You can change Elastic Stack version by setting `ELK_VERSION` in `.env` file and rebuild your images. Any version >= 7.0.0 is compatible with this template.


### Main Features 📜
- Configured as a Production Single Node Cluster.
- Security Enabled By Default.
- Configured to Enable:
  - Logging & Metrics Ingestion
  - Uptime
  - APM
  - Use Docker-Compose and `.env` to configure your entire stack parameters.
- Persist Elasticsearch's data with volume.
- Self-Monitoring Metrics Enabled.
- Embedded Container Healthchecks for elasticsearch container.


#### More points

<details><summary>Expand...</summary>
<p>


- Security enabled by default using Basic license, not Trial.

- Persisting data by default in a volume.

- Run in Production Mode.

- Parameterize credentials in .env instead of hardcoding `elastich:changeme` in every component config.

- Parameterize all other Config like Heap Size.

- Add recommended environment configurations as Ulimits and Swap disable to the docker-compose.

- Configuring the beats and elastic agent:
  - filebeat
  - auditbeat
  - metricbeat
  - packetbeat
  - heartbeat
  - fleet and elastic agent
  - apm-server

</p>
</details>

-----

# Requirements

- [Docker 20.05 or higher](https://docs.docker.com/install/)
- [Docker-Compose 1.29 or higher](https://docs.docker.com/compose/install/)
- 4GB RAM, 4Core CPU, and 30GB

# Setup

1. Clone the Repository
     ```bash
     git clone git@github.com:AhmadRafiee/DevOps_Certification.git
     ```
2. Move to the `observability/elk-stack-single` directory
    ```bash
    $ cd observability/elk-stack-single
    ```
3. Modify environment variables on `.env` file
    ```bash
    $ cat .env
    # domain name information
    DOMAIN_NAME=observability.mecan.ir
    ELASTICSEARCH_SUB_DOMAIN=es
    KIBANA_SUB_DOMAIN=kibana
    
    # hostname
    HOSTNAME=observe-server
    
    # elk version
    ELK_VERSION=7.17.13
    
    # elasticserch auth
    ELASTICSEARCH_USERNAME=elastic
    ELASTICSEARCH_PASSWORD=ChangeMe
    
    # apm secret token
    ELASTICSEARCH_APM_SECRET_TOKEN=ChangeMe
    
    # elasticsearch and kibana url
    ELASTICSEARCH_HOSTNAME=http://elasticsearch:9200
    KIBANA_HOSTNAME=http://kibana:5601
    KIBANA_PUBLIC_URL=https://${KIBANA_SUB_DOMAIN}.${DOMAIN_NAME}
    
    # fleet token and policy id
    FLEET_SERVER_SERVICE_TOKEN="Get from elastic search"
    FLEET_SERVER_POLICY_ID="Get from elastic search"
    
    # set restart policy
    RESTART_POLICY=on-failure
    ```

4. Start elk stack with all beat container
    ```bash
    $ docker-compose pull
    $ docker compose up -d
    ```
5. Visit Kibana at `https://kibana.observability.mecan.ir`

    Default Username: `elastic`, Password: `ChangeMe`


### Good Link:
- https://github.com/Selvamraju007/elastic-docker
- https://github.com/sherifabdlnaby/rubban