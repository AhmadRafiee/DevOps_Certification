# [Docker daemon configuration](https://docs.docker.com/engine/reference/commandline/dockerd/)

## There are two ways for docker daemon Configuration.
- In a first way, you change the docker systemd file.
- In a second way, you add the Docker daemon configuration.

### Change systemd configuration

**Create docker directory**

```bash
mkdir /etc/systemd/system/docker.service.d
````
**Create configuration file**

```bash
touch /etc/systemd/system/docker.service.d/override.conf
```
**Add `--registry-mirror` config on `override.conf`**

```bash
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd --registry-mirror https://docker.DockerMe.ir/
````
**apply this change and check it**

```bash
# updating systemd configuration
systemctl daemon-reload
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


### create docker systemd directory and touch `override.conf` with `systemctl edit`
```bash
# systemctl edit UNIT ==> Edit one or more unit files
systemctl edit docker
```

### Example daemon config file
```bash
[Service]
Environment=HTTP_PROXY=http://127.0.0.1:8123
Environment=HTTPS_PROXY=http://127.0.0.1:8123
Environment=NO_PROXY=localhost,127.0.0.1,repo.dockerme.ir
ExecStart=
ExecStart=/usr/bin/dockerd \
    --registry-mirror https://docker.DockerMe.ir \
    -H tcp://127.0.0.1:2375 \
    --bip 172.21.0.1/24 \
    --ip 0.0.0.0 \
    --data-root /mnt/docker/ \
    --log-opt max-size=100m --log-opt max-file=5
```

## Change daemon configuration

**Create daemon config file**

```bash
touch /etc/docker/daemon.json
```

Either pass the --registry-mirror option when starting dockerd manually, or edit /etc/docker/daemon.json and add the registry-mirrors key and value, to make the change persistent.


```bash
{
  "registry-mirrors": ["https://docker.DockerMe.ir/"]
}
````

The best configuration
```bash
{
  "proxies": {
    "http-proxy": "http://USER:PASS@PROXY_ADDRESS:PORT",
    "https-proxy": "http://USER:PASS@PROXY_ADDRESS:PORT",
    "no-proxy": "localhost,127.0.0.1,.mecan.ir,hub.hamdocker.ir,docker.arvancloud.ir"
    },
 "log-opts": {
    "max-file": "5",
    "max-size": "100m"
  },
 "experimental": true,
 "live-restore": true,
 "registry-mirrors": ["https://hub.hamdocker.ir","https://hub.mecan.ir","https://docker.arvancloud.ir"]
}
```


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


## dockerd command:
```bash
Usage: dockerd COMMAND

A self-sufficient runtime for containers.

Options:
      --add-runtime runtime                   Register an additional OCI compatible runtime (default [])
      --allow-nondistributable-artifacts list Allow push of nondistributable artifacts to registry
      --api-cors-header string                Set CORS headers in the Engine API
      --authorization-plugin list             Authorization plugins to load
      --bip string                            Specify network bridge IP
  -b, --bridge string                         Attach containers to a network bridge
      --cgroup-parent string                  Set parent cgroup for all containers
      --config-file string                    Daemon configuration file (default "/etc/docker/daemon.json")
      --containerd string                     containerd grpc address
      --containerd-namespace string           Containerd namespace to use (default "moby")
      --containerd-plugins-namespace string   Containerd namespace to use for plugins (default "plugins.moby")
      --cpu-rt-period int                     Limit the CPU real-time period in microseconds for the
                                              parent cgroup for all containers
      --cpu-rt-runtime int                    Limit the CPU real-time runtime in microseconds for the
                                              parent cgroup for all containers
      --cri-containerd                        start containerd with cri
      --data-root string                      Root directory of persistent Docker state (default "/var/lib/docker")
  -D, --debug                                 Enable debug mode
      --default-address-pool pool-options     Default address pools for node specific local networks
      --default-cgroupns-mode string          Default mode for containers cgroup namespace ("host" | "private") (default "host")
      --default-gateway ip                    Container default gateway IPv4 address
      --default-gateway-v6 ip                 Container default gateway IPv6 address
      --default-ipc-mode string               Default mode for containers ipc ("shareable" | "private") (default "private")
      --default-runtime string                Default OCI runtime for containers (default "runc")
      --default-shm-size bytes                Default shm size for containers (default 64MiB)
      --default-ulimit ulimit                 Default ulimits for containers (default [])
      --dns list                              DNS server to use
      --dns-opt list                          DNS options to use
      --dns-search list                       DNS search domains to use
      --exec-opt list                         Runtime execution options
      --exec-root string                      Root directory for execution state files (default "/var/run/docker")
      --experimental                          Enable experimental features
      --fixed-cidr string                     IPv4 subnet for fixed IPs
      --fixed-cidr-v6 string                  IPv6 subnet for fixed IPs
  -G, --group string                          Group for the unix socket (default "docker")
      --help                                  Print usage
  -H, --host list                             Daemon socket(s) to connect to
      --host-gateway-ip ip                    IP address that the special 'host-gateway' string in --add-host resolves to.
                                              Defaults to the IP address of the default bridge
      --icc                                   Enable inter-container communication (default true)
      --init                                  Run an init in the container to forward signals and reap processes
      --init-path string                      Path to the docker-init binary
      --insecure-registry list                Enable insecure registry communication
      --ip ip                                 Default IP when binding container ports (default 0.0.0.0)
      --ip-forward                            Enable net.ipv4.ip_forward (default true)
      --ip-masq                               Enable IP masquerading (default true)
      --iptables                              Enable addition of iptables rules (default true)
      --ip6tables                             Enable addition of ip6tables rules (default false)
      --ipv6                                  Enable IPv6 networking
      --label list                            Set key=value labels to the daemon
      --live-restore                          Enable live restore of docker when containers are still running
      --log-driver string                     Default driver for container logs (default "json-file")
  -l, --log-level string                      Set the logging level ("debug"|"info"|"warn"|"error"|"fatal") (default "info")
      --log-opt map                           Default log driver options for containers (default map[])
      --max-concurrent-downloads int          Set the max concurrent downloads for each pull (default 3)
      --max-concurrent-uploads int            Set the max concurrent uploads for each push (default 5)
      --max-download-attempts int             Set the max download attempts for each pull (default 5)
      --metrics-addr string                   Set default address and port to serve the metrics api on
      --mtu int                               Set the containers network MTU
      --network-control-plane-mtu int         Network Control plane MTU (default 1500)
      --no-new-privileges                     Set no-new-privileges by default for new containers
      --node-generic-resource list            Advertise user-defined resource
      --oom-score-adjust int                  Set the oom_score_adj for the daemon (default -500)
  -p, --pidfile string                        Path to use for daemon PID file (default "/var/run/docker.pid")
      --raw-logs                              Full timestamps without ANSI coloring
      --registry-mirror list                  Preferred Docker registry mirror
      --rootless                              Enable rootless mode; typically used with RootlessKit
      --seccomp-profile string                Path to seccomp profile
      --selinux-enabled                       Enable selinux support
      --shutdown-timeout int                  Set the default shutdown timeout (default 15)
  -s, --storage-driver string                 Storage driver to use
      --storage-opt list                      Storage driver options
      --swarm-default-advertise-addr string   Set default address or interface for swarm advertised address
      --tls                                   Use TLS; implied by --tlsverify
      --tlscacert string                      Trust certs signed only by this CA (default "~/.docker/ca.pem")
      --tlscert string                        Path to TLS certificate file (default "~/.docker/cert.pem")
      --tlskey string                         Path to TLS key file (default "~/.docker/key.pem")
      --tlsverify                             Use TLS and verify the remote
      --userland-proxy                        Use userland proxy for loopback traffic (default true)
      --userland-proxy-path string            Path to the userland proxy binary
      --userns-remap string                   User/Group setting for user namespaces
  -v, --version                               Print version information and quit

```

## Daemon configuration file
```bash
{
  "allow-nondistributable-artifacts": [],
  "api-cors-header": "",
  "authorization-plugins": [],
  "bip": "",
  "bridge": "",
  "cgroup-parent": "",
  "cluster-advertise": "",
  "cluster-store": "",
  "cluster-store-opts": {},
  "containerd": "/run/containerd/containerd.sock",
  "containerd-namespace": "docker",
  "containerd-plugin-namespace": "docker-plugins",
  "data-root": "",
  "debug": true,
  "default-address-pools": [
    {
      "base": "172.80.0.0/16",
      "size": 24
    },
    {
      "base": "172.90.0.0/16",
      "size": 24
    }
  ],
  "default-cgroupns-mode": "private",
  "default-gateway": "",
  "default-gateway-v6": "",
  "default-runtime": "runc",
  "default-shm-size": "64M",
  "default-ulimits": {
    "nofile": {
      "Hard": 64000,
      "Name": "nofile",
      "Soft": 64000
    }
  },
  "dns": [],
  "dns-opts": [],
  "dns-search": [],
  "exec-opts": [],
  "exec-root": "",
  "experimental": false,
  "features": {},
  "fixed-cidr": "",
  "fixed-cidr-v6": "",
  "group": "",
  "hosts": [],
  "icc": false,
  "init": false,
  "init-path": "/usr/libexec/docker-init",
  "insecure-registries": [],
  "ip": "0.0.0.0",
  "ip-forward": false,
  "ip-masq": false,
  "iptables": false,
  "ip6tables": false,
  "ipv6": false,
  "labels": [],
  "live-restore": true,
  "log-driver": "json-file",
  "log-level": "",
  "log-opts": {
    "cache-disabled": "false",
    "cache-max-file": "5",
    "cache-max-size": "20m",
    "cache-compress": "true",
    "env": "os,customer",
    "labels": "somelabel",
    "max-file": "5",
    "max-size": "10m"
  },
  "max-concurrent-downloads": 3,
  "max-concurrent-uploads": 5,
  "max-download-attempts": 5,
  "mtu": 0,
  "no-new-privileges": false,
  "node-generic-resources": [
    "NVIDIA-GPU=UUID1",
    "NVIDIA-GPU=UUID2"
  ],
  "oom-score-adjust": -500,
  "pidfile": "",
  "raw-logs": false,
  "registry-mirrors": [],
  "runtimes": {
    "cc-runtime": {
      "path": "/usr/bin/cc-runtime"
    },
    "custom": {
      "path": "/usr/local/bin/my-runc-replacement",
      "runtimeArgs": [
        "--debug"
      ]
    }
  },
  "seccomp-profile": "",
  "selinux-enabled": false,
  "shutdown-timeout": 15,
  "storage-driver": "",
  "storage-opts": [],
  "swarm-default-advertise-addr": "",
  "tls": true,
  "tlscacert": "",
  "tlscert": "",
  "tlskey": "",
  "tlsverify": true,
  "userland-proxy": false,
  "userland-proxy-path": "/usr/libexec/docker-proxy",
  "userns-remap": ""
}

```
