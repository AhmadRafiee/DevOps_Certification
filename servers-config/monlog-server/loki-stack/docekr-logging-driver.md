

### Adding Loki as a Logging Driver
To ship logs to Loki automatically for every container we add to our setup, we need to add the loki logging driver.
The easiest way to add the loki logging driver is with a docker plugin.

```bash
docker plugin install grafana/loki-docker-driver:latest --alias loki --grant-all-permissions
```

Don’t forget to restart the docker daemon after installing the plugin.
```bash
sudo systemctl restart docker
```
After installing the plugin, verify it is enabled.
```bash
docker plugin ls
```

### Using Loki as a Logging Driver
There are two ways, I will cover, to change the logging driver, either directly in the docker compose file or in the `daemon.json` file of the docker daemon.

#### Docker-compose.yaml
The default driver is json-file, but we can easily change it to loki, thanks to the docker plugin we installed earlier.
The loki-url option tells where to ship the logs, which in this case is to our local loki instance.
For a complete options list check the loki logging driver options

```bash
logging:
  driver: loki
  options:
    loki-url: "https://<LOKI_USERNAME>:<LOKI_PASSWORD>@<LOKI_URL>/loki/api/v1/push"
```

#### Daemon.json
We can also change the default logging driver for all containers in a file called `daemon.json`. If you are on Mac its located at `~/.docker/daemon.json`
If you are on linux its located at `/etc/docker/daemon.json`

check default logging driver before change daemon config:
```bash
docker info | grep  Logging
```

Example of `daemon.json`.
Don’t forget to restart the docker daemon afterwards.

```bash
{
    "debug" : true,
    "log-driver": "loki",
    "log-opts": {
        "loki-url": "https://<LOKI_USERNAME>:<LOKI_PASSWORD>@<LOKI_URL>/loki/api/v1/push"
    }
}
```
I prefer adding the logging driver in the docker-compose.yaml directly, because I have more control over the logging driver on a single service level, whereas, with daemon.json, you change the logging driver for all containers.

check default logging driver after change daemon config:
```bash
docker info | grep  Logging
```
