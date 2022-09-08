# Set http proxy on linux

change `PROXY_ADDRESS`, and `PROXY_PORT` then use it.

### Add http proxy on bash - temporary
```bash
export HTTP_PROXY=http://PROXY_ADDRESS:PROXY_PORT
export http_proxy=http://PROXY_ADDRESS:PROXY_PORT
export HTTPS_PROXY=http://PROXY_ADDRESS:PROXY_PORT
export https_proxy=http://PROXY_ADDRESS:PROXY_PORT
export NO_PROXY="localhost,127.0.0.1,172.10.10.0/24,DOMAIN.TLD"
export no_proxy="localhost,127.0.0.1,172.10.10.0/24,DOMAIN.TLD"
```

### Add http proxy on bash - permanent

```bash
cat <<EOF > /etc/profile.d/proxy.sh
export HTTP_PROXY=http://PROXY_ADDRESS:PROXY_PORT
export http_proxy=http://PROXY_ADDRESS:PROXY_PORT
export HTTPS_PROXY=http://PROXY_ADDRESS:PROXY_PORT
export https_proxy=http://PROXY_ADDRESS:PROXY_PORT
export NO_PROXY="localhost,127.0.0.1,172.10.10.0/24,DOMAIN.TLD"
export no_proxy="localhost,127.0.0.1,172.10.10.0/24,DOMAIN.TLD"
EOF
```

### Add http proxy on apt commands - permanent

```bash
cat <<EOF > /etc/apt/apt.conf.d/01proxy
Acquire::http::Proxy "http://PROXY_ADDRESS:PROXY_PORT";
Acquire::https::Proxy "http://PROXY_ADDRESS:PROXY_PORT";
EOF
```

### Add http proxy on git configure - permanent

```bash
vim /etc/gitconfig
[http]
        proxy = http://PROXY_ADDRESS:PROXY_PORT
[https]
        proxy = http://PROXY_ADDRESS:PROXY_PORT
```