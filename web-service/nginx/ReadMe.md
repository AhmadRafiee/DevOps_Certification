# Nginx configuration


### nginx configuration file location

The location of this file will depend on how Nginx was installed. On many Linux distributions, the file will be located at `/etc/nginx/nginx.conf`. If it does not exist there, it may also be at `/usr/local/nginx/conf/nginx.conf` or `/usr/local/etc/nginx/nginx.conf`.

### Nginx Configuration File Description

```bash
# Define the user and the number of worker processes
user nginx;
worker_processes auto;
```
  - `user nginx;`: This sets the user under which the Nginx worker processes will run. nginx is a typical user created during the installation of Nginx.
  - `worker_processes auto;`: This directive sets the number of worker processes. The auto setting adjusts the number of worker processes to the number of available CPU cores.

```bash
# Define error log and pid file
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;
```
  - `error_log /var/log/nginx/error.log warn;`: This specifies the location of the error log file and the logging level. The warn level logs warnings and more severe messages.
  - `pid /var/run/nginx.pid;`: This sets the location of the file that will store the process ID (PID) of the Nginx master process.

```bash
# Define the events block
events {
    worker_connections 1024;
}
```
  - `events { ... }`: This block contains directives that affect the Nginx event handling.
  - `worker_connections 1024;`: This sets the maximum number of simultaneous connections that can be handled by each worker process.

```bash
# Define the http block
http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
```
  - `http { ... }`: This block contains directives for handling HTTP traffic.
  - `include /etc/nginx/mime.types;`: This directive includes the file that maps file extensions to MIME types.
  - `default_type application/octet-stream;`: This sets the default MIME type for files that don’t have a type explicitly defined.

```bash
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';
```
  - `log_format main '...'`: This directive defines a log format named main for the access log. The format specifies what information will be logged for each request.

```bash
    access_log /var/log/nginx/access.log main;
```
  - `access_log /var/log/nginx/access.log main;`: This sets the location of the access log file and specifies the log format to use (in this case, the main format).

```bash
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
```
  - `sendfile on;`: This enables the use of the sendfile() system call to efficiently send files to the client.
  - `tcp_nopush on;`: This enables TCP_CORK, which optimizes the transmission of data by not sending partial frames.
  - `tcp_nodelay on;`: This disables Nagle’s algorithm, which can help improve performance for some types of applications by sending small packets immediately.
  - `keepalive_timeout 65;`: This sets the timeout for keep-alive connections with the client.
  - `types_hash_max_size 2048;`: This sets the maximum size of the types hash tables. Adjusting this can help improve performance for servers with many MIME types.

```bash
    include /etc/nginx/conf.d/*.conf;
}
```
  - `include /etc/nginx/conf.d/*.conf;`: This includes additional configuration files from the `/etc/nginx/conf.d` directory. This is useful for modularizing your configuration and maintaining different configurations for different sites or services.

### Description of Nginx Server Block Components

**Sample Config:**
```bash
server {
    listen 80;
    server_name example.com www.example.com;

    location / {
        root /var/www/html;
        index index.html index.htm;
    }

    error_page 404 /404.html;
    location = /404.html {
        internal;
    }

    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
        internal;
    }
}
```

**Description:**
  - `server { ... }`: The server block defines a virtual server. It contains directives and nested blocks that configure how Nginx handles requests for a specific domain or IP address.
  - `listen 80;`: This directive tells Nginx to listen on port 80, which is the default port for HTTP traffic. You can change this to another port number if needed.
  - `server_name example.com www.example.com;`: This directive specifies the domain names that this server block will respond to. Requests for example.com and www.example.com will be handled by this server block.
  - `location / { ... }`: The location block defines how requests for specific URIs (Uniform Resource Identifiers) are processed.
  - `location / { ... }`: This location block matches all URIs that start with / (i.e., it matches all requests).
  - `root /var/www/html;`: This directive specifies the root directory for the location block. Nginx will look for files in this directory when processing requests.
  - `index index.html index.htm;`: This directive defines the index files that Nginx will look for when a directory is requested. If a user requests http://example.com/, Nginx will try to serve index.html or index.htm from the root directory.
  - `error_page 404 /404.html;`: This directive specifies a custom error page for 404 Not Found errors. When a requested resource is not found, Nginx will serve the /404.html file.
  - `location = /404.html { ... }`: This location block matches the exact URI /404.html.
  - `internal;`: This directive makes the location internal, meaning it cannot be directly requested by a client. It's used only for serving the error page.
  - `error_page 500 502 503 504 /50x.html;`: This directive specifies a custom error page for server errors (500, 502, 503, 504). When one of these errors occurs, Nginx will serve the /50x.html file.
  - `location = /50x.html { ... }`This location block matches the exact URI /50x.html.
  - `internal;`: This directive makes the location internal, meaning it cannot be directly requested by a client. It's used only for serving the error page.
  - `root /var/www/default;`: This directive specifies the root directory for the server block. Nginx will look for files in this directory when processing requests.
  - `listen 443 ssl default_server;`: This directive tells Nginx to listen on port 443 for HTTPS traffic and to designate this server block as the default server for HTTPS.
  - `ssl_certificate /etc/nginx/ssl/default.crt;`: This specifies the path to the SSL certificate.
  - `ssl_certificate_key /etc/nginx/ssl/default.key;`: This specifies the path to the SSL certificate key.


### Description of Nginx Location Block

**Basic Location Block**
```bash
location / {
    root /var/www/html;
    index index.html index.htm;
}
```
  - `location / { ... }`: This matches all URIs that start with / (i.e., it matches all requests).
  - `root /var/www/html;`: Specifies the root directory for this location block.
  - `index index.html index.htm;`: Specifies the index files to look for when a directory is requested.

**Specific Path Location**
```bash
location /images/ {
    root /var/www/media;
}
```
  - `location /images/ { ... }`: This matches URIs that start with `/images/`.
    - `root /var/www/media;`: Specifies the root directory for this location block. Requests to `/images/` will be served from `/var/www/media/images/`.

**Exact Match Location**
```bash
location = /favicon.ico {
    log_not_found off;
    access_log off;
}
```
  - `location = /favicon.ico { ... }`: This matches exactly the URI /favicon.ico.
  - `log_not_found off;`: Disables logging of not found errors for this location.
  - `access_log off;`: Disables access logging for this location.

**Redirect with try_files**
```bash
location / {
    try_files $uri $uri/ /index.html;
}
```

  - `location / { ... }`: This matches all URIs that start with /.
  - `try_files $uri $uri/ /index.html;`: This directive tries to serve the requested URI as a file, then as a directory. If neither exists, it serves `/index.html`.

**Proxy Pass to Backend Server**

```bash
location /api/ {
    proxy_pass http://backend_server;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```
  - `location /api/ { ... }`: This matches URIs that start with /api/.
  - `proxy_pass http://backend_server;`: Forwards requests to the backend server (replace backend_server with the actual backend server address).
  - `proxy_set_header ...;`: Sets headers to pass along with the proxied request.
  - `proxy_set_header Host $host;`: Sets the Host header in the proxied request to the value of the original Host header.
  - `proxy_set_header X-Real-IP $remote_addr;`: Passes the client's IP address to the backend server.
  - `proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;`: Adds the client's IP address to the X-Forwarded-For header.
  - `proxy_set_header X-Forwarded-Proto $scheme;`: Passes the original request scheme (http or https) to the backend server.

**Location with Basic Authentication**
```bash
location /admin/ {
    auth_basic "Restricted Content";
    auth_basic_user_file /etc/nginx/.htpasswd;
}
```
  - `location /admin/ { ... }`: This matches URIs that start with /admin/.
  - `auth_basic "Restricted Content";`: Enables basic authentication with the specified realm name.
  - `auth_basic_user_file /etc/nginx/.htpasswd;`: Specifies the password file for basic authentication.


**Serving Static Content with alias**
```bash
location /downloads/ {
    alias /var/www/files/;
    autoindex on;
}
```
  - `location /downloads/ { ... }`: This matches URIs that start with /downloads/.
  - `alias /var/www/files/;`: Specifies the directory to serve files from. Note that alias replaces the entire URI part.
  - `autoindex on;`: Enables automatic directory listing if no index file is found.
  - `index index.html index.htm;`: This directive defines the index files that Nginx will look for when a directory is requested.


**Denying Access**
```bash
location /private/ {
    deny all;
}
```
  - `location /private/ { ... }`: This matches URIs that start with /private/.
  - `deny all;`: Denies access to this location.

**Custom Error Pages**
```bash
location / {
    error_page 404 /404.html;
    error_page 500 502 503 504 /50x.html;
}
```
  - `location / { ... }`: This matches all URIs that start with /.
  - `error_page 404 /404.html;`: Specifies the custom error page for 404 Not Found errors.
  - `error_page 500 502 503 504 /50x.html;`: Specifies the custom error page for server errors.


### Description of Common Directives on location
  - `root`: Specifies the root directory for the location block. The full file path is constructed by appending the URI to this directory.
  - `alias`: Specifies the directory to serve files from, but unlike root, alias replaces the entire URI part.
  - `try_files`: Tries to serve the requested URI as a file or directory. If neither exists, it serves the specified fallback URI.
  - `proxy_pass`: Forwards the request to another server.
  - `proxy_set_header`: Sets headers for the proxied request.
  - `auth_basic`: Enables basic HTTP authentication.
  - `auth_basic_user_file`: Specifies the password file for HTTP authentication.
  - `deny`: Denies access to the specified location.
  - `autoindex`: Enables or disables automatic directory listing.
  - `satisfy any;`: This directive allows access if any of the access conditions are met. In this case, it means that a request will be allowed if it satisfies either the IP address restriction or the Basic Authentication requirement.
  - `allow 192.168.1.0/24;`: This directive allows access from the IP address range 192.168.1.0 to 192.168.1.255.

#### Additional Notes:
  - **root vs. alias:** The root directive specifies the document root for the server or location block, appending the URI to this path. The alias directive specifies the exact path to serve the files from, replacing the entire URI part.
  - **try_files:** This directive is useful for handling pretty URLs, where you might want to serve an index file or show a 404 error if the file or directory does not exist.
  - **autoindex:** Enabling autoindex allows users to see a directory listing if no index file is found, which can be useful for directories meant to serve downloadable files.

### Description of Upstream Context Components:
```bash
upstream backend {
    server backend1.example.com;
    server backend2.example.com;
    server backend3.example.com;
}

server {
    listen 80;
    server_name example.com;

    location / {
        proxy_pass http://backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```
  - `upstream backend { ... }`:The upstream block defines a group of backend servers that Nginx will use for proxying requests.
  - `backend`: The name given to this upstream block. This name is used in the proxy_pass directive to refer to this group of servers.
  - `server backend1.example.com;`: server backend1.example.com;: This directive specifies a backend server. You can list multiple servers within the upstream block.

#### Load Balancing Methods:
Nginx supports several load balancing methods that can be specified within the upstream block:

```bash
upstream backend {
    server backend1.example.com;
    server backend2.example.com;
    server backend3.example.com;
}
```
  - **Round-robin (default):** Distributes requests to the servers in a circular manner.

```bash
upstream backend {
    least_conn;
    server backend1.example.com;
    server backend2.example.com;
    server backend3.example.com;
}
```
  - **Least Connections:** Distributes requests to the server with the fewest active connections.

```bash
upstream backend {
    ip_hash;
    server backend1.example.com;
    server backend2.example.com;
    server backend3.example.com;
}
```
  - **IP Hash:** Distributes requests based on the client IP address, ensuring the same client is always directed to the same server.

```bash
upstream backend {
    hash $request_uri consistent;
    server backend1.example.com;
    server backend2.example.com;
    server backend3.example.com;
}
```
  - **Generic Hash:** Distributes requests based on a custom hash key.


#### Server Parameters
Each server directive within an upstream block can be configured with several parameters:

```bash
upstream backend {
    server backend1.example.com weight=3;
    server backend2.example.com;
}
```
  - **weight=number:** Assigns a weight to the server. Higher weights mean more requests are sent to that server.

```bash
upstream backend {
    server backend1.example.com max_fails=3;
    server backend2.example.com;
}
```
  - **max_fails=number:** Specifies the number of failed attempts after which the server is considered unavailable.

```bash
upstream backend {
    server backend1.example.com fail_timeout=30s;
    server backend2.example.com;
}
```
  - **fail_timeout=time:** Specifies the time during which the server will be considered unavailable after max_fails failures.

```bash
upstream backend {
    server backend1.example.com;
    server backend2.example.com backup;
}
```
  - **backup:** Designates the server as a backup. It will only be used when the primary servers are unavailable.


#### Additional Notes:
 - **Health Checks:** Nginx can be configured to perform health checks on backend servers to ensure they are available before sending requests. This requires the Nginx Plus version or a third-party module.
 - **Sticky Sessions:** To maintain session persistence (sticky sessions), you can use the ip_hash method or use a third-party module for more advanced configurations.


**Testing Configuration:** Ensure to test the Nginx configuration after making changes:
```bash
nginx -t
```

**Reload Nginx:** Apply the changes by reloading Nginx:

```bash
sudo systemctl reload nginx
```

### Nginx Redirection and Rewrite configuration:

#### Simple Redirection with return
The return directive is a straightforward way to perform redirections.
```bash
server {
    listen 80;
    server_name example.com;

    location /old-page {
        return 301 /new-page;
    }

    location / {
        root /var/www/html;
        index index.html index.htm;
    }
}
```
  - `location /old-page { ... }`: This block matches requests to /old-page.
  - `return 301 /new-page;`: This directive sends a 301 Moved Permanently response, redirecting the client to /new-page.

#### Redirection with rewrite
The rewrite directive allows for more complex URL manipulations using regular expressions.

```bash
server {
    listen 80;
    server_name example.com;

    location / {
        rewrite ^/old-section/(.*)$ /new-section/$1 permanent;
    }
}
```

  - `rewrite ^/old-section/(.*)$ /new-section/$1 permanent;`: This directive matches any URL starting with /old-section/, captures the rest of the URL, and redirects it to /new-section/ with the captured part appended. The permanent keyword sends a 301 Moved Permanently response.

#### Enforcing HTTPS

Redirecting HTTP requests to HTTPS is a common use case for redirection to ensure secure communication.

```bash
server {
    listen 80;
    server_name example.com;

    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name example.com;

    ssl_certificate /etc/nginx/ssl/example.com.crt;
    ssl_certificate_key /etc/nginx/ssl/example.com.key;

    location / {
        root /var/www/html;
        index index.html index.htm;
    }
}

```

  - `listen 80;`: Listens for HTTP requests.
  - `return 301 https://$host$request_uri;`: Redirects all HTTP requests to the corresponding HTTPS URL.
  - `listen 443 ssl;`: Listens for HTTPS requests.
  - `ssl_certificate` and `ssl_certificate_key`: Specifies the SSL certificate and key files.


#### Redirection with Conditional Logic
You can use if statements for conditional redirections.

```bash
server {
    listen 80;
    server_name example.com;

    location / {
        if ($request_uri ~* "^/old-page") {
            return 301 /new-page;
        }

        root /var/www/html;
        index index.html index.htm;
    }
}
```
  - `*if ($request_uri ~ "^/old-page") { ... }**`: Checks if the request URI matches /old-page.
  - `return 301 /new-page;`: Redirects the client to /new-page.

#### Redirecting to an External URL
Redirect to an external website or URL.

```bash
server {
    listen 80;
    server_name example.com;

    location /redirect-me {
        return 302 https://www.external.com;
    }

    location / {
        root /var/www/html;
        index index.html index.htm;
    }
}
```
  - `return 302 https://www.external.com;`: Sends a 302 Found response, redirecting the client to an external URL `https://www.external.com`.

**301 vs. 302 Redirects:**
  - `301 Moved Permanently:` Indicates that the resource has permanently moved to a new location. This redirect is cached by browsers.
  - `302 Found:` Indicates a temporary redirection. Browsers do not cache this redirect.

### Configure Nginx to Use SSL/TLS:
Here is a full configuration example:

```bash
server {
    listen 80;
    server_name example.com www.example.com;

    # Redirect all HTTP requests to HTTPS
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name example.com www.example.com;

    ssl_certificate /etc/nginx/ssl/example.com.crt;
    ssl_certificate_key /etc/nginx/ssl/example.com.key;

    # Recommended security settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers "EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH";
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_session_tickets off;

    # Enable OCSP Stapling
    ssl_stapling on;
    ssl_stapling_verify on;
    resolver 8.8.8.8 8.8.4.4 valid=300s;
    resolver_timeout 5s;

    # Add HTTP Strict Transport Security (HSTS)
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;

    # Protect against clickjacking
    add_header X-Frame-Options DENY;

    # Enable XSS protection
    add_header X-XSS-Protection "1; mode=block";

    # Prevent MIME type sniffing
    add_header X-Content-Type-Options nosniff;

    # Specify a content security policy
    add_header Content-Security-Policy "default-src 'self'";

    root /var/www/html;
    index index.html index.htm;

    location / {
        try_files $uri $uri/ =404;
    }
}
```
**Explanation of Configuration Components**
  - `listen 80;`: Listens for HTTP traffic.
  - `server_name example.com www.example.com;`: Specifies the domain names.
  - `return 301 https://$host$request_uri;`: Redirects all HTTP requests to HTTPS.
  - `listen 443 ssl;`: Listens for HTTPS traffic.
  - `ssl_certificate /etc/nginx/ssl/example.com.crt;`: Path to the SSL certificate.
  - `ssl_certificate_key /etc/nginx/ssl/example.com.key;`: Path to the private key.
  - `ssl_protocols TLSv1.2 TLSv1.3;`: Specifies allowed SSL/TLS protocols.
  - `ssl_prefer_server_ciphers on;`: Prefer server ciphers over client ciphers.
  - `ssl_ciphers "...";`: Specifies the ciphers to use.
  - `ssl_session_cache shared:SSL:10m;`: Configures SSL session caching.
  - `ssl_session_timeout 10m;`: Sets the timeout for cached sessions.
  - `ssl_session_tickets off;`: Disables session tickets for added security.
  - `ssl_stapling on;`: Enables OCSP stapling.
  - `ssl_stapling_verify on;`: Verifies the OCSP response.
  - `resolver 8.8.8.8 8.8.4.4 valid=300s;`: Sets the DNS resolvers for OCSP.
  - `resolver_timeout 5s;`: Sets the resolver timeout.
  - `Strict-Transport-Security`: Enforces HSTS.
  - `X-Frame-Options DENY`: Protects against clickjacking.
  - `X-XSS-Protection "1; mode=block"`: Enables XSS protection.
  - `X-Content-Type-Options nosniff`: Prevents MIME type sniffing.
  - `Content-Security-Policy "default-src 'self'"`: Sets a basic content security policy.
  - `root /var/www/html;`: Specifies the document root.
  - `index index.html index.htm;`: Defines index files.
  - `location / { ... }`: Handles requests to the root URL.

