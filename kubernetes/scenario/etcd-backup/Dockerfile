ARG VERSION=v3.5.6
FROM quay.io/coreos/etcd:${VERSION}

RUN apt-get update \
    && apt-get install -y ca-certificates \
    && update-ca-certificates \
    && which curl || apt install -y curl \
    && curl https://dl.min.io/client/mc/release/linux-amd64/mc -o /usr/local/bin/mc \
    && chmod +x /usr/local/bin/mc \
    && mc --version \
    && apt-get clean autoclean \
    && apt-get autoremove --yes \
    && rm -rf /var/lib/{apt,dpkg,cache,log}/

COPY --chmod=0766 entrypoint.sh /opt/entrypoint.sh
ENTRYPOINT [ "bash", "/opt/entrypoint.sh" ]