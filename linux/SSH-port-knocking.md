# SSH port knocking setup using `knockd` and `iptables`

- [SSH port knocking setup using `knockd` and `iptables`](#ssh-port-knocking-setup-using-knockd-and-iptables)
  - [Port Knocking with knockd](#port-knocking-with-knockd)
  - [Scenario Summary](#scenario-summary)
  - [Step 1: Install knockd](#step-1-install-knockd)
  - [Step 2: Enable knockd on systemd](#step-2-enable-knockd-on-systemd)
  - [Step 3: Configure /etc/knockd.conf](#step-3-configure-etcknockdconf)
  - [Step 4: Lock down SSH port by default](#step-4-lock-down-ssh-port-by-default)
  - [Step 5: Start knockd and enable service](#step-5-start-knockd-and-enable-service)
  - [Step 6: Knock from a client machine](#step-6-knock-from-a-client-machine)
  - [Optional Security Tips](#optional-security-tips)

## Port Knocking with knockd
Port knocking is a lightweight security mechanism that protects services (like SSH) by keeping their ports closed by default and opening them only after a client sends a specific sequence of connection attempts (knocks) to predefined ports.

This project demonstrates how to configure and use `knockd` with `iptables` to:

  - Hide the SSH port from unauthorized access
  - Open SSH access only after a valid knock sequence
  - Automatically close the port after a reverse sequence or timeout
  - Add an extra layer of security without needing a VPN or complex firewall setups

It’s a simple yet effective way to reduce exposure to brute-force attacks and port scanners.



## Scenario Summary
  - SSH (usually on port 22) is closed by default on the server firewall.
  - A secret sequence of TCP "knocks" (like 7000, 8000, 9000) must be sent to specific ports.
  - Only after the correct knock sequence, the server opens port 22 (SSH) for the client’s IP.
  - After a short time or reverse sequence, the SSH port can be closed again.

## Step 1: Install knockd
On Ubuntu/Debian:

```bash
sudo apt install knockd
```

## Step 2: Enable knockd on systemd
Edit the default configuration:
```bash
sudo vim /etc/default/knockd
```

Update it like this:
```bash
START_KNOCKD=1
KNOCKD_OPTS="-i enp0s3"
```
Replace `enp0s3` with your actual network interface (check it using ip a).

## Step 3: Configure /etc/knockd.conf
Open the config file:

```bash
sudo vim /etc/knockd.conf
```

Paste this config:

```
[options]
    logfile = /var/log/knockd.log

[openSSH]
    sequence    = 7000,8000,9000
    seq_timeout = 5
    command     = /sbin/iptables -I INPUT -s %IP% -p tcp --dport 22 -j ACCEPT
    tcpflags    = syn

[closeSSH]
    sequence    = 9000,8000,7000
    seq_timeout = 5
    command     = /sbin/iptables -D INPUT -s %IP% -p tcp --dport 22 -j ACCEPT
    tcpflags    = syn
```

## Step 4: Lock down SSH port by default
On the server, run:

```bash
sudo iptables -A INPUT -p tcp --dport 22 -j DROP
```

This blocks SSH access unless a valid knock sequence is received.
## Step 5: Start knockd and enable service

```bash
sudo systemctl enable knockd
sudo systemctl restart knockd
```

Make sure it’s running:

```bash
sudo systemctl status knockd
```

## Step 6: Knock from a client machine
Install knock client:

```bash
sudo apt install knockd
```

Send the knock sequence:
```bash
knock your.server.ip 7000 8000 9000
```

Wait 1–2 seconds, then:

```bash
ssh youruser@your.server.ip
```

To close the SSH port again:

```bash
knock your.server.ip 9000 8000 7000
```

## Optional Security Tips
  - Use UDP knock sequence for more stealth (knock -u).
  - Change the default SSH port (e.g., to 2222).
  - Combine with fail2ban to block brute-force knockers.
  - Use a VPN or whitelist known IPs as an additional layer.

