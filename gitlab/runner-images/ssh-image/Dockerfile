FROM alpine:latest
RUN apk add --no-cache --update curl git openssh \
    && apk add --no-cache ca-certificates \
    && rm -rf /var/cache/apk

RUN wget https://dl.minio.io/client/mc/release/linux-amd64/mc \
    && chmod +x mc \
    && mv mc /usr/local/bin/ \
    && mc --version