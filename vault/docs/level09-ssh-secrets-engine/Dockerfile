FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends openssh-server curl unzip sshpass && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /run/sshd /var/log && \
    useradd -m -s /bin/bash -p '*' developer && \
    useradd -m -s /bin/bash -p '*' admin && \
    useradd -m -s /bin/bash -p '*' ops

COPY vault-ssh-helper /usr/local/bin/vault-ssh-helper
RUN chmod +x /usr/local/bin/vault-ssh-helper

COPY sshd_config          /etc/ssh/sshd_config
COPY pam_sshd_otp         /etc/pam.d/sshd
COPY vault-ssh-helper.hcl /etc/vault-ssh-helper.d/config.hcl
COPY entrypoint.sh        /entrypoint.sh

RUN chmod +x /entrypoint.sh

EXPOSE 22 2223
CMD ["/entrypoint.sh"]
