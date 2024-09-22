# Docker
![Docker](images/docker.png)

- [Docker](#docker)
    - [Installation docker on Debian](#installation/ReadMe.md)

    - [Configuration docker](#configuration)
      - [Configuration docker daemon](#configuration/docker_daemon_config.md)
      - [Configuration docker bridge network](#configuration/bridge-networking.md)
      - [Configuration docker networking](#configuration/networking.md)
      - [Configuration docker overlay network](#configuration/overlay-networking.md)
      - [Configuration docker Logging plugin](#configuration/plugin-logging.md)
      - [Configuration docker Storage plugin](#configuration/plugin-volumes.md)
      - [Configuration docker macvlan network](#configuration/macvlan-network-sample.md)

    - [Dockerfile](#Dockerfile)
      - [Dockerfile multistage](#Dockerfile/Dockerfile_multistage)
      - [Dockerfile best practice](#Dockerfile/dockerfile_best_practice.md)
      - [Dockerfile nginx sample](#Dockerfile/dockerfile_nginx_simple.md)
      - [Dockerfile perl sample](#Dockerfile/dockerfile_perl)
      - [Dockerfile static-site](#Dockerfile/static-site)
      - [Dockerfile flask-app](#Dockerfile/flask-app)

    - [Compose File](#compose-file)
      - [portainer service](#compose-file/portainer-compose.yml)
      - [registry service](#compose-file/registry-compose.yml)
      - [traefik service](#compose-file/traefik-compose.yml)
      - [wordpress service](#compose-file/wordpress-compose.yml)
      - [awesome compose](#compose-file/awesome-compose)

    - [docker scenario](#scenario)
      - [wordpress with nginx](#scenario/wordpress-with-nginx.md)
      - [registry with nginx](#scenario/registry-with-nginx.md)
      - [avatars project](#scenario/avatars)
      - [elk stack project](#scenario/elk)
      - [loki stack project](#scenario/logging)
      - [prometheus stack project](#scenario/monitoring)
      - [redis cluster project](#scenario/redis_cluster_sample)
      - [sample app project](#scenario/sample-app)
      - [voting app project](#scenario/voting-app)
      - [web service nginx project](#scenario/web-service-nginx)

    - [docker swarm](#swarm)
      - [deploy voting app with swarm](#scenario/deploying_app_with_swarm.md)