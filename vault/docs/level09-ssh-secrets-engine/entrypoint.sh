#!/bin/bash
set -e

# Install Vault CA public key if provided via environment
if [ -n "$VAULT_SSH_CA_KEY" ]; then
  echo "$VAULT_SSH_CA_KEY" > /etc/ssh/trusted-user-ca-keys.pem
fi

# Generate host keys if not present
ssh-keygen -A 2>/dev/null

# Start sshd (foreground, both ports via single instance)
exec /usr/sbin/sshd -D -e
