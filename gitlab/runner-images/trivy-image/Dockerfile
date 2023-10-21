FROM alpine:3.11
RUN apk add --no-cache --update curl docker-cli \
    && rm -rf /var/cache/apk \
    && curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin v0.19.2 \
    && curl -sSL -o /tmp/trivy-gitlab.tpl https://github.com/aquasecurity/trivy/raw/v0.19.2/contrib/gitlab.tpl \
    && trivy --version