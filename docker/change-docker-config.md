


## Change docker daemon configuration

**Create daemon config file**

```bash
sudo touch /etc/docker/daemon.json
```

Either pass the --registry-mirror option when starting dockerd manually, or edit /etc/docker/daemon.json and add the registry-mirrors key and value, to make the change persistent.


```bash
{
  "registry-mirrors": ["https://hub.hamdocker.ir/"]
}
````

**apply this change and check it**

```bash
# restart docker service
systemctl restart docker 
# check docker service status 
systemctl status docker
```

**check docker config**
```bash
docker info | grep -A1 "Registry Mirrors"  

# sample output
 Registry Mirrors:
  https://docker.DockerMe.ir/
```

**Best docker daemon configuration**

```bash
sudo vim /etc/docker/daemon.json

{
  "registry-mirrors": ["https://hub.hamdocker.ir/"],
  "insecure-registries": [http://example.com],
  "bip": "172.100.0.1/24",
  "data-root": "/mnt/data",
  "log-driver": "json-file",
  "log-level": "info",
  "log-opts": {
    "cache-disabled": "false",
    "cache-max-file": "5",
    "cache-max-size": "20m",
    "cache-compress": "true",
    "labels": "MeCanHost",
    "max-file": "5",
    "max-size": "10m"
  }
}
```
**apply these change**

```bash
# restart docker service
systemctl restart docker 
# check docker service status 
systemctl status docker
```
