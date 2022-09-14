### Create the required directories
```bash
# create directory
mkdir -p auth data

# check
tree
```

### Create the main nginx configuration. Paste this code block into a new file called auth/nginx.conf:
```bash
vim nginx.conf

events {
    worker_connections  1024;
}

http {

  upstream docker-registry {
    server registry:5000;
  }

  ## Set a variable to help us decide if we need to add the
  ## 'Docker-Distribution-Api-Version' header.
  ## The registry always sets this header.
  ## In the case of nginx performing auth, the header is unset
  ## since nginx is auth-ing before proxying.
  map $upstream_http_docker_distribution_api_version $docker_distribution_api_version {
    '' 'registry/2.0';
  }

  server {
    listen 443 ssl;
    server_name repo.MeCan.ir;

    # SSL
    ssl_certificate /etc/nginx/conf.d/cert.pem;
    ssl_certificate_key /etc/nginx/conf.d/key.pem;

    # Recommendations from https://raymii.org/s/tutorials/Strong_SSL_Security_On_nginx.html
    ssl_protocols TLSv1.1 TLSv1.2;
    ssl_ciphers 'EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH';
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;

    # disable any limits to avoid HTTP 413 for large image uploads
    client_max_body_size 0;

    # required to avoid HTTP 411: see Issue #1486 (https://github.com/moby/moby/issues/1486)
    chunked_transfer_encoding on;

    location /v2/ {
      # Do not allow connections from docker 1.5 and earlier
      # docker pre-1.6.0 did not properly set the user agent on ping, catch "Go *" user agents
      if ($http_user_agent ~ "^(docker\/1\.(3|4|5(?!\.[0-9]-dev))|Go ).*$" ) {
        return 404;
      }

      # To add basic authentication to v2 use auth_basic setting.
      auth_basic "Registry realm";
      auth_basic_user_file /etc/nginx/conf.d/nginx.htpasswd;

      ## If $docker_distribution_api_version is empty, the header is not added.
      ## See the map directive above where this variable is defined.
      add_header 'Docker-Distribution-Api-Version' $docker_distribution_api_version always;

      proxy_pass                          http://docker-registry;
      proxy_set_header  Host              $http_host;   # required for docker client's sake
      proxy_set_header  X-Real-IP         $remote_addr; # pass on real client's IP
      proxy_set_header  X-Forwarded-For   $proxy_add_x_forwarded_for;
      proxy_set_header  X-Forwarded-Proto $scheme;
      proxy_read_timeout                  900;
    }
  }
  server {
      listen 80;
      server_name repo.MeCan.ir;
      return 301 https://$host$request_uri;
  }
}
```

### Create a password file auth/nginx.htpasswd for “ahmad” and "DevOps_training_with_DockerMe”
```bash
# create htpasswd file
sudo htpasswd -c auth/nginx.htpasswd ahmad

# check
cat auth/nginx.htpasswd
```

### create certificate files to the auth/ directory.
```bash 
# certificate location
CERT_LOCATION=./auth/

# generate key and cert
openssl req -x509 -nodes -newkey \
rsa:4096 -days 365 \
-keyout $CERT_LOCATION/key.pem \
-subj "/C=IR/ST=Iran/L=Tehran/O=MeCan/OU=IT/CN=MeCan.ir/emailAddress=rafiee1001@gmail.com" \
-out $CERT_LOCATION/cert.pem 

# cehck certificate
openssl x509 -text -noout -in $CERT_LOCATION/cert.pem

# check 
tree 
```

### docker network create
```bash
docker network create hub
docker network ls 
```

## run with docker commands
### run registry container
```bash
# run registry container
docker run -d -p 127.0.0.1:5000:5000 -v ${PWD}/data:/var/lib/registry --net hub --restart=always --name registry registry:2

# check
docker ps 
docker logs -f registry
```

### run web container
```bash
# run web container
docker run -d -p 443:443 -p 80:80 -v ${PWD}/auth:/etc/nginx/conf.d -v ${PWD}/nginx.conf:/etc/nginx/nginx.conf:ro \
--net hub --restart=always --name web nginx:alpine

# check
docker ps 
docker logs -f web
```

## run with docker compose
```bash
nginx:
  image: "nginx:alpine"
  ports:
    - 443:443
    - 80:80
  links:
    - registry:registry
  volumes:
    - ./auth:/etc/nginx/conf.d
    - ./nginx.conf:/etc/nginx/nginx.conf:ro

registry:
  image: registry:2
  volumes:
    - ./data:/var/lib/registry
```

### run compose file and check it
```bash
# run
docker-compose up -d
# check
docker-compose ps
docker-compose logs -f
```

### For the use of the self-sign certificate, we should configure insecure-registry option
```bash
#      --insecure-registry list                Enable insecure registry communication
vim /etc/systemd/system/docker.service.d/override.conf
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd --insecure-registry https://repo.MeCan.ir

# systemd reload and restart docker
systemctl daemon-reload
systemctl restart docker
systemctl status docker

# check
docker info | grep -A1 "Insecure Registries:"
```

### login to registry
```bash
docker login https://repo.MeCan.ir -u ahmad -p DevOps_training_with_DockerMe
```

### Image Tag and Push to local Registry
```bash
# tag image
docker tag nginx:alpine repo.MeCan.ir/nginx:alpine
# push image
docker push repo.MeCan.ir/nginx:alpine
# check repository
curl -u "ahmad:DevOps_training_with_DockerMe" -k https://repo.MeCan.ir/v2/_catalog
```
