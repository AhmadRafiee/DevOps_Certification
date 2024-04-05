### haproxy and keepalived install and configuration
### On API loadbalancer nodes
```bash
echo "install haproxy and keepalived service"
apt install -y haproxy keepalived

echo "copy and move haproxy config"
cat /etc/haproxy/haproxy.cfg
cat <<EOT >> /etc/haproxy/haproxy.cfg
listen Stats-Page
  bind *:8000
  mode http
  stats enable
  stats hide-version
  stats refresh 10s
  stats uri /
  stats show-legends
  stats show-node

frontend fe-apiserver
   bind 0.0.0.0:6443
   mode tcp
   option tcplog
   default_backend be-apiserver

backend be-apiserver
   mode tcp
   option tcp-check
   balance roundrobin
   default-server inter 10s downinter 5s rise 2 fall 2 slowstart 60s maxconn 250 maxqueue 256 weight 100
   server control-plane-1 ${master1_ip}:6443 check
   server control-plane-2 ${master2_ip}:6443 check
   server control-plane-3 ${master3_ip}:6443 check
EOT
cat /etc/haproxy/haproxy.cfg

echo "check haproxy config file"
haproxy -c -f /etc/haproxy/haproxy.cfg

echo "Enable and start haproxy service"
{
systemctl enable haproxy
systemctl restart haproxy
systemctl is-active --quiet haproxy && echo -e "\e[1m \e[96m haproxy service: \e[30;48;5;82m \e[5mRunning \e[0m" || echo -e "\e[1m \e[96m docker service: \e[30;48;5;196m \e[5mNot Running \e[0m"
}

echo "check haproxy status page"
netstat -ntlp | grep 8000
```
### On Master API loadbalancer node
```bash
cat <<EOT > /etc/keepalived/keepalived.conf
global_defs {
   enable_script_security
   script_user root
}

vrrp_script check_haproxy {
   script "killall -0 haproxy"
   interval 2
   weight 2
   }

vrrp_instance KUBE_API_LB {
   state MASTER
   interface ens160
   virtual_router_id 51
   priority 101
   # The virtual ip address shared between the two loadbalancers
   virtual_ipaddress {
      ${vip_api}/32
   }
   track_script {
      check_haproxy
   }
}
EOT
cat /etc/keepalived/keepalived.conf

echo "check keepalived config file"
keepalived -t -l -f /etc/keepalived/keepalived.conf

echo "Enable and start keepalived service"
{
systemctl enable keepalived
systemctl restart keepalived
systemctl is-active --quiet keepalived && echo -e "\e[1m \e[96m keepalived service: \e[30;48;5;82m \e[5mRunning \e[0m" || echo -e "\e[1m \e[96m docker service: \e[30;48;5;196m \e[5mNot Running \e[0m"
}

echo "check vip"
ip a | grep 192.168.1.44/32
```
### On Slave API loadbalancer node
```bash
cat <<EOT > /etc/keepalived/keepalived.conf
global_defs {
   enable_script_security
   script_user root
}
# Script used to check if HAProxy is running
vrrp_script check_haproxy {
   script "killall -0 haproxy"
   interval 2
   weight 2
}

vrrp_instance KUBE_API_LB {
   state BACKUP
   interface ens160
   virtual_router_id 51
   priority 100
   virtual_ipaddress {
      ${vip_api}/32
   }
   track_script {
      check_haproxy
   }
}
EOT

cat /etc/keepalived/keepalived.conf
echo "check keepalived config file"
keepalived -t -l -f /etc/keepalived/keepalived.conf

echo "Enable and start keepalived service"
{
systemctl enable keepalived
systemctl restart keepalived
systemctl is-active --quiet keepalived && echo -e "\e[1m \e[96m keepalived service: \e[30;48;5;82m \e[5mRunning \e[0m" || echo -e "\e[1m \e[96m docker service: \e[30;48;5;196m \e[5mNot Running \e[0m"
}

echo "check vip"
ip a | grep 192.168.1.44/32
```
