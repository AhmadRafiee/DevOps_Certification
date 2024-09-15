# Docker plugin - Volumes

## Blockbridge installation with docker
```bash
curl -sSL https://get.blockbridge.com/container | sh

# sample output
=================================================================================
Blockbridge Storage Container 4.3.0-5544.1 (7bad60f1-2479-4939-b457-271165daa4eb)
Mode: converged

Generated Credentials (may not reflect current system state)

System admin API token:  1/1RGEpVLjN6AqQu1gtPWDzAabQWncs2S1ROCxhekvzvzFEYSlUuM24Q
System admin username:   system
System admin password:   263cfc0940d06a219bdac593abef87c0
Default user username:   default
Default user password:   b8570b319c0a858294acda49a444000a
Volume plugin API token: 1/z0D6Yj2w8x0T+8JRaxThCIQYabWEoz/mPPNs061SWnrvQPpiPbDyXA
=================================================================================
```

## Plugin Installation​
```bash
# install plugin
docker plugin install --alias block blockbridge/volume-plugin BLOCKBRIDGE_API_HOST="YOUR HOST" BLOCKBRIDGE_API_KEY="YOUR KEY"
# for example
docker plugin install --alias block blockbridge/volume-plugin BLOCKBRIDGE_API_HOST="172.16.10.153" BLOCKBRIDGE_API_KEY="1/1RGEpVLjN6AqQu1gtPWDzAabQWncs2S1ROCxhekvzvzFEYSlUuM24Q"

# check
docker plugin ls​
```
## Create volume with blockbridge driver
```bash
# create volume
docker volume create --name default --driver block default

# cehck
docker volume ls -f driver=block
```

## Create volume with capacity option and blockbridge driver
```bash
# create volume
docker volume create --name custom --driver block --opt capacity=4GiB

# cehck
docker volume ls -f driver=block
```

## Create container with volume on blockbridge storage
```bash
# create container
docker run --name test --volume-driver block -v implicit:/data -d -it busybox sh

# check
docker ps
```

## Refrence
  - https://www.blockbridge.com/container/
  - https://docs.docker.com/engine/extend/legacy_plugins/