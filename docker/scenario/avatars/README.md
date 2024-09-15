# Docker Samples :: Avatars 🤪
Avatars is a small sample project for Docker demonstration purposes.

It consists of a Python web API backend to generate avatars and a Javascript SPA (single page app) frontend.
If you are not a Python or Javascript guru, don't panic!

## Usage
To get started, clone this repository locally:
```shell
git clone https://github.com/dockersamples/avatars.git
```
All subsequent commands assume they are run from the root repository directory
(i.e. `avatars/` folder).

Run `make help` to see a list of available targets.

### Tilt
You'll need to first install Tilt and prerequisites (Docker + development Kubernetes cluster).

Run `tilt up` or `make tilt`.
All resources will be deployed to the namespace and cluster as determined by the active Kubernetes config context.

* Tilt web interface: http://localhost:10350/
* Avatars frontend: http://localhost:5735/
* Avatars API: `curl http://localhost:5734/api/avatar/spec`

### Docker Compose with file watch
Run `make compose`.

* Avatars frontend: http://localhost:5735/

Compose launches the services and attaches in file watch mode.
Run `docker compose -p avatars logs -f` from a separate terminal to stream logs. 

### Kubernetes (Docker Desktop)
> ℹ️ If you haven't already, open the Docker Desktop dashboard and enable
> Kubernetes from `Settings > Kubernetes > ☑️ Enable Kubernetes` and apply.

Run `make kubernetes`.
All resources will be deployed to the `avatars` namespace in the `docker-desktop` Kubernetes cluster.

* Avatars frontend: http://localhost:5735/

Buildx builds images and Kubernetes creates `Deployment`s and `Service`s.
The images are not pushed to a registry, as Docker Desktop's Kubernetes
integration runs the images directly from the Docker Engine image store using
[cri-dockerd][] (formerly known as `dockershim`).

Run `kubectl --context=docker-desktop --namespace=avatars logs -l='app.kubernetes.io/part-of=dockersamples_avatars' from a separate terminal to stream logs.

[cri-dockerd]: https://github.com/Mirantis/cri-dockerd


## Simple Compose Watch Test


```
git clone https://github.com/dockersamples/avatars
cd avatars
docker compose up -d
```

## Initiate the Watch

```
docker compose watch
```

## Generate a graphviz graph from your compose file

```
docker compose alpha viz
```
