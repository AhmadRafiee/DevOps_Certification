# Running nginx web service with docker

## Step1: running nginx with docker commands

### Run Simple Nginx Service
```bash
docker run --name nginx -p 80:80 -d nginx:alpine
```

### create nginx directory
```bash
mkdir -p ./conf.d
mkdir -p ./certs
tree ./nginx
```

### create self sign certificate with openssl command and check it
```bash
# certificate location
CERT_LOCATION=./certs

# generate key and cert
openssl req -x509 -nodes -newkey \
rsa:4096 -days 365 \
-keyout $CERT_LOCATION/key.pem \
-subj "/C=IR/ST=Iran/L=Tehran/O=DockerMe/OU=IT/CN=DockerMe.ir/emailAddress=rafiee1001@gmail.com" \
-out $CERT_LOCATION/cert.pem 

# cehck certificate
openssl x509 -text -noout -in $CERT_LOCATION/cert.pem

# check nginx directory
tree nginx
```
### create sample nginx.conf
```bash

user  nginx;
worker_processes  auto;

error_log  /var/log/nginx/error.log notice;
pid        /var/run/nginx.pid;


events {
    worker_connections  1024;
}


http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile        on;
    #tcp_nopush     on;

    keepalive_timeout  65;

    #gzip  on;

    include /etc/nginx/conf.d/*.conf;
}
```

### create sample configuration
```bash
vim ./conf.d/weavescope.conf
server {
  listen 443 ssl http2;
  server_name weavescope.dockerme.ir;

  # SSL
  ssl_certificate /etc/nginx/certs/cert.pem;
  ssl_certificate_key /etc/nginx/certs/key.pem;
 
  location / {
  proxy_pass     http://weavescope:4040;
  proxy_http_version 1.1;
  proxy_set_header Upgrade $http_upgrade;
  proxy_set_header Connection "upgrade";
  proxy_set_header Host $host;
  add_header Strict-Transport-Security "max-age=63072000; includeSubdomains";
  add_header X-XSS-Protection "1; mode=block";
  add_header X-Content-Type-Options nosniff;
  add_header X-Frame-Options DENY;
  add_header 'Referrer-Policy' 'strict-origin';
  add_header X-Powered-By "Ahmad Rafiee | DockerMe.ir";
  proxy_set_header  X-Real-IP         $remote_addr; # pass on real client's IP
  proxy_set_header  X-Forwarded-For   $proxy_add_x_forwarded_for;
  proxy_set_header  X-Forwarded-Proto $scheme;
  proxy_connect_timeout   90;
  proxy_send_timeout      90;
  proxy_read_timeout      90;
  proxy_buffers           32 4k;
  #Http Authentication
  auth_basic "Access to the staging site";
  auth_basic_user_file /etc/nginx/conf.d/.htpasswd;
  }
}
server {
    listen 80;
    server_name weavescope.dockerme.ir;
    return 301 https://$host$request_uri;
}
```

### Restricting Access with HTTP Basic Authentication

Creating a Password File:

```bash
# Verify that apache2-utils (Debian, Ubuntu) or httpd-tools (RHEL/CentOS/Oracle Linux) is installed.
apt install apache2-utils

# Create a password file and a first user. Run the htpasswd utility with the -c flag (to create a new file), the file pathname as the first argument, and the username as the second argument
sudo htpasswd -c ./conf.d/.htpasswd user1

# Configuring NGINX and NGINX Plus for HTTP Basic Authentication
location /api {
    auth_basic           “Administrator’s Area”;
    auth_basic_user_file /etc/nginx/conf.d/.htpasswd; 
}
```
### Combining Basic Authentication with Access Restriction by IP Address
```bash
# Combining Basic Authentication with Access Restriction by IP Address
location /api {
    #...
    deny  192.168.1.2;
    allow 192.168.1.1/24;
    allow 127.0.0.1;
    deny  all;
}
```

### Run with other configuration
```bash
docker run -d --name nginx --hostname nginx -p 80:80 -p 443:443 -v ${PWD}/nginx.conf:/etc/nginx/nginx.conf:ro -v ${PWD}/conf.d:/etc/nginx/conf.d/ -v ${PWD}/certs:/etc/nginx/certs nginx:alpine
```

## Step2: running nginx web service with compose file and docker-compose

### compose file 
```bash 
---
version: '3.4'

networks:
  http_net:
    external: true
  web_net:
    external: false

services:
  web:
    image: nginx:alpine
    restart: on-failure
    container_name: web
    ports:
      - 443:443
      - 80:80
    volumes:
      - ./certs/:/etc/nginx/certs
      - ./conf.d/:/etc/nginx/conf.d
    networks:
      - http_net
      - web_net
```

### check and run compose file
```bash
docker-compose config
docker-compose up -d 
docker-compose logs -f 
docker-compose ps
```


### 🔗 Refrence link:

[Nginx Restricting Access](https://docs.nginx.com/nginx/admin-guide/security-controls/configuring-http-basic-authentication/)