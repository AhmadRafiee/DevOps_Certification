# Dockerfile sample
### Simple nginx dockerfile
```bash
FROM ubuntu:latest
LABEL maintainer="Ahmad Rafiee <rafiee1001@gmail.com>"
RUN apt update \
    && apt install -y vim nginx

# forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log

EXPOSE 80
    CMD ["nginx", "-g", "daemon off;"]
```
### Build this dockerfile
```bash
docker build -t <TAG_NAME> -f <Dockerfile path> .
# For example
docker build -t nginx:test .
``` 
### Run nginx image
```bash 
docker run -d --name web -p 80:80 nginx:test
```