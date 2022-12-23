# Running wordpress with docker
## 

## Step1: running wordpress with docker commands
### pull all needed images 
```bash
docker pull wordpress:latest
docker pull nginx:latest
docker pull mysql:5.7
```

### create network and check it 
```bash
docker network create --driver bridge wp-net
docker network ls
docker inspect wp-net
```

### create volume and check it 
```bash
docker volume create --name wp-data
docker volume create --name db-data
docker volume ls
docker inspect wp-data
docker inspect db-data
```

### run mysql service and check it
```bash
docker run -d --name mysql --hostname mysql \
--network=wp-net --restart=always \
--mount=source=db-data,target=/var/lib/mysql \
-e MYSQL_ROOT_PASSWORD=sdvfsacsiojoijsaefawefmwervs \
-e MYSQL_DATABASE=MeCan \
-e MYSQL_USER=MeCan \
-e MYSQL_PASSWORD=sdvfsacsiojoijsaefawefmwervs \
mysql:5.7

# check mysql services
docker ps
docker stats --no-stream mysql
docker logs mysql
docker exec -i mysql mysql -u root -psdvfsacsiojoijsaefawefmwervs  <<< "show databases"
```

### run wordpress service and check it
```bash
docker run -d --name wordpress --hostname wordpress \
--network=wp-net --restart=always \
--mount=source=wp-data,target=/var/www/html/ \
-e WORDPRESS_DB_PASSWORD=sdvfsacsiojoijsaefawefmwervs \
-e WORDPRESS_DB_HOST=mysql:3306 \
-e WORDPRESS_DB_USER=MeCan \
-e WORDPRESS_DB_NAME=MeCan \
wordpress:latest

# check wordpress services
docker ps
docker stats --no-stream
docker logs wordpress 
```

### create nginx directory
```bash
mkdir -p ./nginx/conf.d
mkdir -p ./nginx/certs
tree ./nginx
```

### create nginx config file for wordpress proxy pass
```bash
vim ./nginx/conf.d/wordpress.conf
server {
  listen 443;
  server_name wp.MeCan.ir;

  # SSL
  ssl on;
  ssl_certificate /etc/nginx/certs/cert.pem;
  ssl_certificate_key /etc/nginx/certs/key.pem;

  location / {
    proxy_pass            http://wordpress:80;
    proxy_set_header  Host              $http_host;   # required for docker client's sake
    proxy_set_header  X-Real-IP         $remote_addr; # pass on real client's IP
    proxy_set_header  X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header  X-Forwarded-Proto $scheme;
    add_header X-Powered-By "Ahmad Rafiee | DockerMe.ir";
    }
 }

 server {
    listen 80;
    server_name wp.MeCan.ir;
    return 301 https://$host$request_uri;
}
```

### create self sign certificate with openssl command and check it
```bash
# certificate location
CERT_LOCATION=./nginx/certs

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

### run nginx services and check it
```bash
docker run -itd --name nginx --hostname nginx \
--network=wp-net --restart=always \
-v ${PWD}/nginx/conf.d:/etc/nginx/conf.d \
-v ${PWD}/nginx/certs:/etc/nginx/certs \
-p 80:80 -p 443:443 \
nginx:latest

# check nginx services
docker ps
docker stats --no-stream
docker logs nginx
curl -I -L -k http://127.0.0.1
```

### backup databases
```bash
docker exec -i mysql mysqldump -u root -psdvfsacsiojoijsaefawefmwervs --all-databases --single-transaction --quick  > full-backup-$(date +%F).sql

# check backup
ls | grep full-backup-*.sql
du -sh full-backup-*.sql
```

## Step2: running wordpress with compose-file and docker-compose

### compose file
```bash
---
version: '3.8'

networks:
  wp_net:
    name: wp_net
    driver_opts:
      com.docker.network.bridge.name: wp_net

volumes:
  wp_db:
    name: wp_db
  wp_wp:
    name: wp_wp

services:
  db:
    image: mysql:5.7
    container_name: mysql
    volumes:
      - wp_db:/var/lib/mysql
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: sdfascsdvsfdvweliuoiquowecefcwaefef
      MYSQL_DATABASE: MeCan
      MYSQL_USER: MeCan
      MYSQL_PASSWORD: sdfascsdvsfdvweliuoiquowecefcwaefef
    networks:
      - wp_net

  wordpress:
    image: wordpress:latest
    container_name: wordpress
    volumes:
      - wp_wp:/var/www/html/
    depends_on:
      - db
    restart: always
    environment:
      WORDPRESS_DB_HOST: db:3306
      WORDPRESS_DB_USER: MeCan
      WORDPRESS_DB_NAME: MeCan
      WORDPRESS_DB_PASSWORD: sdfascsdvsfdvweliuoiquowecefcwaefef
    ports:
      - 8000:80
    networks:
      - wp_net

  nginx:
    image: nginx:alpine
    container_name: nginx
    restart: always
    depends_on:
      - wordpress
    volumes:
      - ./nginx/conf.d:/etc/nginx/conf.d
      - ./nginx/certs:/etc/nginx/certs
    ports:
      - 80:80
      - 443:443
    networks:
      - wp_net
```
### check and run compose file
```bash
docker-compose config
docker-compose up -d
docker-compose logs -f
docker-compose ps
```
