# Level 11 — SSH OTP (One-Time Password)

### Requirements:
  - **Vault Service is Running** from level 0
  - **Vault Address:** `https://vault.lab.mecan.ir`
  - **Auth:** Root token `myroot` (dev mode only)
  - **Tools:** install `jq` command
  - **ssh service** from level 9

---

## Overview

SSH OTP is a simpler alternative to signed certificates. Instead of managing
a CA, Vault generates a **one-time password** for each SSH session. The SSH
server verifies it against Vault via `vault-ssh-helper`. Once used, the OTP
is destroyed — replay attacks are impossible.

```
Admin ──── generate OTP for user@server ──> Vault ──── OTP (UUID) ──> User
User  ──── ssh ops@server (enter OTP as password) ────────────────> SSH Server
SSH Server ── vault-ssh-helper verifies OTP ──> Vault ──── valid/invalid
                                                            ↓ valid: drops OTP
```

### OTP vs Signed Certificates

| Property              | OTP                              | Signed Cert (Level 9)             |
|-----------------------|----------------------------------|-----------------------------------|
| Setup complexity      | Low (no CA management)           | Medium (CA + roles)               |
| User workflow         | Get OTP, type it as password     | Sign public key, SSH with cert    |
| Server-side verify    | Live call to Vault per login     | Offline — cert carries signature  |
| Vault availability    | Required at login time           | Not required (cert is self-contained) |
| Replay attack         | Impossible — OTP consumed on use | Impossible — cert expires         |
| Best for              | Simple/ad-hoc access             | Production services               |

---

## 11.1 Infrastructure: vault-ssh-helper

`vault-ssh-helper` is a small binary that runs on the SSH server.
PAM calls it during authentication to verify the OTP against Vault.

### SSH server sshd_config

```
Port 22      # cert auth (Level 9)
Port 2223    # OTP auth (this level)

UsePAM yes
PasswordAuthentication no
PubkeyAuthentication yes
ChallengeResponseAuthentication no

# Cert auth on port 22
TrustedUserCAKeys /etc/ssh/trusted-user-ca-keys.pem
AuthorizedKeysFile /dev/null

# OTP auth on port 2223 — keyboard-interactive only
Match LocalPort 2223
    PubkeyAuthentication no
    ChallengeResponseAuthentication yes
    KbdInteractiveAuthentication yes
    AuthenticationMethods keyboard-interactive
```

### PAM config `/etc/pam.d/sshd`

```
auth requisite pam_exec.so quiet expose_authtok log=/var/log/vault-ssh.log \
    /usr/local/bin/vault-ssh-helper -dev -config=/etc/vault-ssh-helper.d/config.hcl
auth optional pam_unix.so not_set_pass use_first_pass nodelay
account required pam_nologin.so
account required pam_unix.so
session required pam_limits.so
session required pam_unix.so
```

### vault-ssh-helper config `/etc/vault-ssh-helper.d/config.hcl`

```hcl
vault_addr        = "http://hashicorp_vault:8200"
ssh_mount_point   = "ssh"
ca_cert           = "-dev"
allowed_roles     = "*"
allowed_cidr_list = "0.0.0.0/0"
```

---

## 11.2 Create OTP Role in Vault

The SSH engine must already be enabled (see Level 9).

```bash
curl -X POST https://vault.lab.mecan.ir/v1/ssh/roles/otp-role \
  -H "X-Vault-Token: myroot" \
  -H "Content-Type: application/json" \
  -d '{
    "key_type": "otp",
    "default_user": "ops",
    "allowed_users": "ops,developer",
    "cidr_list": "0.0.0.0/0"
  }'
```

![opt-role](../image/10.opt-role.png)

---

## 11.3 Generate an OTP

An admin (or CI/CD pipeline) generates an OTP for a specific user and
target server IP. The `ip` field must be the SSH **server's** IP address.

```bash
# Get server IP
SSH_SERVER_IP=$(docker inspect vault_ssh_server \
  --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')
echo $SSH_SERVER_IP

curl -X POST https://vault.lab.mecan.ir/v1/ssh/creds/otp-role \
  -H "X-Vault-Token: myroot" \
  -H "Content-Type: application/json" \
  -d "{\"username\": \"ops\", \"ip\": \"$SSH_SERVER_IP\"}" | jq
```

Response:
```json
{
  "data": {
    "key_type": "otp",
    "username": "ops",
    "ip":       "172.19.0.4",
    "key":      "a7b1ce97-c3dc-5aa2-5d4a-74a955296ee1",
    "port":     22
  }
}
```

The `key` is the one-time password — a UUID that works exactly once.

---

## 11.4 SSH Login with OTP

The user enters the OTP as the password when prompted:

```bash
ssh -p 2223 ops@localhost
# Password: a7b1ce97-c3dc-5aa2-5d4a-74a955296ee1
```

Or non-interactively with `sshpass`:

```bash
SSHPASS="a7b1ce97-c3dc-5aa2-5d4a-74a955296ee1" sshpass -e \
  ssh -o PreferredAuthentications=keyboard-interactive \
  -p 2223 ops@localhost
```

---

## 11.5 Access Control Test Results

| Test                                          | Result  |
|-----------------------------------------------|---------|
| OTP login — first use succeeds                | ✅      |
| Same OTP reused — second use fails (exit 5)   | ✅      |
| Wrong/random OTP — denied                     | ✅      |
| Cert auth on port 2223 (disabled) — denied    | ✅      |

---

## 11.6 Live End-to-End Test

```bash
# Step 1: Get server IP
SSH_SERVER_IP=$(docker inspect vault_ssh_server \
  --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')
echo $SSH_SERVER_IP
# 172.18.0.4

# Step 2: Generate a fresh OTP
OTP=$(curl -s -X POST https://vault.lab.mecan.ir/v1/ssh/creds/otp-role \
  -H "X-Vault-Token: myroot" \
  -H "Content-Type: application/json" \
  -d "{\"username\": \"ops\", \"ip\": \"$SSH_SERVER_IP\"}" | jq -r '.data.key')
echo $OTP
# 3320ffbd-30af-7ea0-27d9-51df4ec29e76

# Step 3: SSH login with the new OTP
SSHPASS="$OTP" sshpass -e \
  ssh -o PreferredAuthentications=keyboard-interactive \
  -o StrictHostKeyChecking=no \
  -p 2223 ops@localhost "whoami && hostname"
# ops
# 9d3252662083
```

After this login the OTP is permanently destroyed — reusing `$OTP` returns permission denied.

---

## 11.7 How vault-ssh-helper Works

When a user authenticates on port 2223:

1. `sshd` triggers PAM keyboard-interactive
2. PAM calls `pam_exec.so` which runs `vault-ssh-helper`
3. `vault-ssh-helper` reads the entered password (OTP) from stdin
4. It calls `POST /v1/sys/wrapping/lookup` to verify the OTP against Vault
5. Vault validates: is this OTP valid? Is the username/IP correct?
6. If valid: Vault **destroys** the OTP immediately, helper returns success
7. If invalid/already used: helper returns failure, PAM denies access

The OTP is consumed at step 6 — any subsequent use fails at step 5.

---

## API Reference

| Operation          | Method | Path                            |
|--------------------|--------|---------------------------------|
| Create OTP role    | POST   | `/v1/ssh/roles/<name>`          |
| Generate OTP       | POST   | `/v1/ssh/creds/<role>`          |
| Verify OTP (helper)| —      | `vault-ssh-helper -verify-only` |
| List roles         | LIST   | `/v1/ssh/roles`                 |
