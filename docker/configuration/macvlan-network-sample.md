# docker macvlan network driver sample

### 1. Create a Macvlan Network
You need to create a Docker macvlan network that bridges to your physical network interface (like eth0 or ens192).

```bash
docker network create -d macvlan \
    --subnet=192.168.1.0/24 \
    --gateway=192.168.1.1 \
    -o parent=wlp2s0 \
    my_macvlan_network
```

**Explanation:**

**-d macvlan:** Specifies the driver (macvlan).
**--subnet:** The subnet in which your containers will operate.
**--gateway:** Your network gateway (router).
**-o parent=wlp2s0:** The network interface that will act as the parent (change wlp2s0 to match your system).

**check network:**
```bash
docker network ls
docker network inspect my_macvlan_network
```

### 2. Create a Container on the Macvlan Network
Now, let's create a container and assign it an IP address on the macvlan network.

```bash
docker run -d --name my_macvlan_container \
    --network my_macvlan_network \
    --ip 192.168.1.10 \
    nginx
```
This command starts an Nginx container connected to the my_macvlan_network network with an IP address of 192.168.1.10.

**check container:**
```bash
docker ps
docker logs my_macvlan_container
docker container inspect --format '{{ .NetworkSettings.Networks.my_macvlan_network.IPAddress }}' my_macvlan_container
```

### 3. Configure Routing (Optional)
If your Docker host needs to communicate with the containers on the macvlan network, you might need to set up routing. You can create another macvlan interface on the host to facilitate this.

```bash
sudo ip link add macvlan0 link wlp2s0 type macvlan mode bridge
sudo ip addr add 192.168.1.100/24 dev macvlan0
sudo ip link set macvlan0 up
```
Now the Docker host can communicate with the containers directly using this interface (macvlan0).

### 4. Verify the Configuration
You can verify the configuration by running:

```bash
docker network inspect my_macvlan_network
```
This will display details of the network and the containers attached to it.

### 4. Clean up
```bash
docker rm -f my_macvlan_container
docker network rm my_macvlan_network
sudo ip link delete macvlan0
```