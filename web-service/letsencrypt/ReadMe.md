# Let's Encrypt

Let's Encrypt is a free, automated, and open Certificate Authority (CA) provided by the Internet Security Research Group (ISRG). It issues digital certificates for Transport Layer Security (TLS) encryption, which are used to secure HTTPS websites. The main goal of Let's Encrypt is to make it easy to obtain and install certificates to enable HTTPS on websites, promoting a more secure internet.

### Key Features of Let's Encrypt
- **Free:** Certificates issued by Let's Encrypt are free of charge.
- **Automated:** The process of obtaining and renewing certificates can be automated.
- **Open:** The service is provided by an open and transparent organization, with community involvement.
- **Secure:** Provides certificates that support the latest TLS features.
- **Widely Trusted:** Certificates are trusted by all major browsers and operating systems.

### Let's Encrypt's Challenges:
Let's Encrypt's Certbot supports several challenge types for domain validation. Each challenge type proves to the Certificate Authority (CA) that you control the domain for which you are requesting a certificate. Here are the primary challenge types supported by Certbot:

#### 1. HTTP-01 Challenge
The HTTP-01 challenge requires you to demonstrate control over a domain by responding to a specific HTTP request.

```bash
sudo certbot certonly --nginx -d example.com -d www.example.com --preferred-challenges http
```

  - Certbot will create a temporary file on your web server in the .well-known/acme-challenge/ directory.
  - Let's Encrypt will send an HTTP request to http://example.com/.well-known/acme-challenge/<token>.
  - If Let's Encrypt can retrieve the token, the challenge is passed, and the certificate is issued.

#### 2. DNS-01 Challenge
The DNS-01 challenge requires you to demonstrate control over a domain by adding a specific DNS TXT record.

```bash
sudo certbot certonly --manual --preferred-challenges dns -d example.com -d www.example.com
```
  - Certbot provides a DNS TXT record that you need to add to your domain's DNS configuration.
  - Let's Encrypt will query the DNS record to verify that it exists.
  - If Let's Encrypt can find the TXT record, the challenge is passed, and the certificate is issued.

#### 3. TLS-ALPN-01 Challenge
The TLS-ALPN-01 challenge requires you to demonstrate control over a domain by configuring a TLS server to respond to a specific challenge using the Application-Layer Protocol Negotiation (ALPN) extension.

```bash
sudo certbot certonly --standalone --preferred-challenges tls-alpn-01 -d example.com -d www.example.com
```
  - Certbot will start a temporary TLS server that listens on port 443.
  - Let's Encrypt will connect to the server and validate that the correct challenge response is presented via the ALPN extension.
  - If Let's Encrypt can validate the challenge, the certificate is issued.


### Additional Certbot Commands and Options

**Automatic Renewal:** Certbot automatically sets up a cron job or systemd timer for renewing certificates. You can manually test the renewal process using:

```bash
sudo certbot renew --dry-run
```

**Standalone Mode:**If you do not have a web server running, you can use Certbot in standalone mode. This starts a temporary web server to respond to HTTP-01 challenges.

```bash
sudo certbot certonly --standalone -d example.com -d www.example.com
```

**Manual Mode:**For greater control, especially with DNS-01 challenges, you can use manual mode.

```bash
sudo certbot certonly --manual --preferred-challenges dns -d example.com -d www.example.com
```

### Step-by-Step Guide to Using Let's Encrypt with Certbot

#### 1. Install Certbot:
```bash
sudo apt update
sudo apt install certbot python3-certbot-nginx
```

#### 2. Obtain a Certificate
Use Certbot to obtain a certificate and configure Nginx. Certbot will automatically edit your Nginx configuration to use the new certificate.

```bash
sudo certbot --nginx
```

#### 3. Automating Certificate Renewal
Let's Encrypt certificates are only valid for 90 days. However, Certbot can automatically renew them. A cron job is usually set up during the installation of Certbot to handle renewals.
To manually test the renewal process, you can use:

```bash
sudo certbot renew --dry-run
```

#### Let's Encrypt plugin commands:

```bash
# Nginx Plugin
sudo certbot --nginx -d example.com -d www.example.com

# Apache Plugin
sudo certbot --apache -d example.com -d www.example.com

# Standalone Plugin
sudo certbot certonly --standalone -d example.com -d www.example.com

# Manual Plugin
sudo certbot certonly --manual --preferred-challenges dns -d example.com -d www.example.com

# DNS Plugins
## Example (Cloudflare):
sudo certbot -a dns-cloudflare --dns-cloudflare-credentials ~/.secrets/certbot/cloudflare.ini -i nginx -d example.com -d www.example.com

## Example (AWS Route 53):
sudo certbot -a dns-route53 -i nginx -d example.com -d www.example.com

# Webroot Plugin
sudo certbot certonly --webroot -w /var/www/html -d example.com -d www.example.com
```

### Single command and get certificate non-interactive

The certonly command of Certbot allows you to obtain or renew certificates without modifying your web server's configuration files.
```bash
sudo certbot certonly \
    --webroot \
    -w /var/www/html \
    -d example.com -d www.example.com \
    --agree-tos \
    --email your_email@example.com \
    --no-eff-email \
    --force-renewal
```
  - `--webroot`: Specifies the webroot directory where Certbot will place temporary files for validation.
  - `-w /var/www/html`: Replace with your actual webroot path.
  - `-d example.com -d www.example.com`: Specifies the domain names for which you want to obtain the certificate.
  - `--agree-tos`: Automatically agrees to the Let's Encrypt terms of service.
  - `--email your_email@example.com`: Specifies your email address for renewal and security notifications.
  - `--no-eff-email`: Do not share your email address with the Electronic Frontier Foundation.
  - `--force-renewal`: Force renewals (useful for automation scripts).
