## Basic Configuration for Reverse Proxy and SSL Termination
Here's a step-by-step guide to set up HAProxy as a reverse proxy with SSL termination:

**Step 1:** Install HAProxy
On a Debian/Ubuntu system, you can install HAProxy using:

```bash
sudo apt-get update
sudo apt-get install haproxy
```

**Step 2:** Obtain SSL Certificate
You need an SSL certificate and private key. This can be obtained from a Certificate Authority (CA) or generated using Let's Encrypt.

Combine the certificate and key into a single file:

```bash
cat /etc/ssl/private/your_domain.crt /etc/ssl/private/your_domain.key > /etc/ssl/private/haproxy.pem
```

**Step 3:** Configure HAProxy
Edit the HAProxy configuration file, typically located at /etc/haproxy/haproxy.cfg.

```bash
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon
    tune.ssl.default-dh-param 2048

defaults
    log global
    option httplog
    option dontlognull
    timeout connect 5000ms
    timeout client  50000ms
    timeout server  50000ms

frontend http_front
    bind *:80
    bind *:443 ssl crt /etc/ssl/private/haproxy.pem
    redirect scheme https code 301 if !{ ssl_fc }
    default_backend http_back

backend http_back
    balance roundrobin
    option httpchk GET /health
    http-check expect status 200
    server web1 192.168.1.1:80 check
    server web2 192.168.1.2:80 check
```

**Explanation of Configuration:**

**1. Global Section:**
    - Configures logging, runtime chroot, and user/group under which HAProxy runs.
    - Sets the default DH parameter size for SSL.

**2. Defaults Section:**
    - Specifies default logging, timeout, and connection options.

**3. Frontend Section:**
    - `bind *:80`: Binds HAProxy to port 80 for HTTP traffic.
    - `bind *:443 ssl crt /etc/ssl/private/haproxy.pem`: Binds HAProxy to port 443 for HTTPS traffic and specifies the SSL certificate.
    - `redirect scheme https code 301 if !{ ssl_fc }`: Redirects HTTP traffic to HTTPS.
    - `default_backend http_back`: Specifies the default backend to use for incoming traffic.

**4. Backend Section**:
    - `balance roundrobin`: Distributes requests using the round-robin algorithm.
    - `option httpchk GET /health`: Performs HTTP health checks on backend servers.
    - `http-check expect status 200`: Expects a 200 OK response for health checks.
    - `server web1 192.168.1.1:80 check`: Specifies a backend server and its health check configuration.
    - `server web2 192.168.1.2:80 check`: Specifies another backend server.

**Advanced Configuration Options:**

**Using Let's Encrypt for SSL Certificates**
To automate SSL certificate issuance and renewal with Let's Encrypt, you can use a tool like `certbot` and configure HAProxy to use the generated certificates.

1. Install Certbot:

```bash
sudo apt-get install certbot
```

2. Generate Certificate:

```bash
sudo certbot certonly --standalone -d your_domain.com
```

3. Configure HAProxy to Use Certbot Certificates:

Update your HAProxy configuration to use the Certbot-generated certificates:

```bash
frontend http_front
    bind *:80
    bind *:443 ssl crt /etc/letsencrypt/live/your_domain.com/fullchain.pem crt /etc/letsencrypt/live/your_domain.com/privkey.pem
    redirect scheme https code 301 if !{ ssl_fc }
    default_backend http_back
```

**Enabling HTTP/2**
HAProxy supports HTTP/2 for encrypted connections. To enable HTTP/2, add the alpn h2,http/1.1 directive to the SSL binding in the frontend configuration.

```bash
frontend http_front
    bind *:443 ssl crt /etc/ssl/private/haproxy.pem alpn h2,http/1.1
```

**Final Configuration Example**

Here is the final configuration file, incorporating all the above elements:

```bash
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon
    tune.ssl.default-dh-param 2048

defaults
    log global
    option httplog
    option dontlognull
    timeout connect 5000ms
    timeout client  50000ms
    timeout server  50000ms

frontend http_front
    bind *:80
    bind *:443 ssl crt /etc/ssl/private/haproxy.pem alpn h2,http/1.1
    redirect scheme https code 301 if !{ ssl_fc }
    default_backend http_back

backend http_back
    balance roundrobin
    option httpchk GET /health
    http-check expect status 200
    server web1 192.168.1.1:80 check
    server web2 192.168.1.2:80 check

listen stats
    bind *:8404
    stats enable
    stats uri /haproxy?stats
    stats refresh 10s
    stats auth admin:password
```

**Conclusion**
By configuring HAProxy as a reverse proxy with SSL termination, you can efficiently manage your web traffic, offload SSL processing from backend servers, and enhance the security and performance of your application. With advanced options like HTTP/2 support and automated certificate management, HAProxy becomes a powerful tool in your infrastructure toolkit.

## Enabling HAProxy Statistics
To enable and configure HAProxy statistics, you need to add a listen or frontend section in your HAProxy configuration file. Here’s a step-by-step guide to set up and access the HAProxy statistics:

**Configure the HAProxy Statistics Section**
Add the following section to your haproxy.cfg file:

```bash
listen stats
    bind *:8404
    mode http
    stats enable
    stats uri /haproxy?stats
    stats refresh 10s
    stats show-node
    stats auth admin:password
    stats admin if LOCALHOST
```

**Explanation of Configuration**
    - `listen stats`: Creates a new listener named stats.
    - `bind *:8404`: Binds the statistics page to port 8404 on all interfaces.
    - `mode http`: Sets the mode to HTTP for accessing the statistics page.
    - `stats enable`: Enables the statistics reporting.
    - `stats uri /haproxy?stats`: Sets the URI path to access the statistics page.
    - `stats refresh 10s`: Refreshes the statistics page every 10 seconds.
    - `stats show-node`: Displays the HAProxy node name on the stats page.
    - `stats auth admin:password`: Protects the statistics page with basic authentication (username: admin, password: password).
    - `stats admin if LOCALHOST`: Allows administrative actions (e.g., stopping servers) only from localhost.

**Accessing HAProxy Statistics**
Start or Restart HAProxy:
After adding the statistics configuration, start or restart the HAProxy service to apply the changes.

```bash
sudo systemctl restart haproxy
```

**Access the Statistics Page:**
Open a web browser and navigate to the HAProxy statistics page. For example:

```bash
http://your-haproxy-server:8404/haproxy?stats
```

**Authenticate:**
Enter the username and password configured in the stats auth directive (in this case, `admin` and `password`).

## HAProxy Using ACLs

Once defined, ACLs can be used with actions like `http-request`, `use_backend`, `redirect`, and `deny`.

**Example: Blocking Traffic Based on IP**

```bash
frontend http_front
    bind *:80
    acl blocked_ip src 192.168.2.0/24
    http-request deny if blocked_ip
    default_backend http_back
```

**Example: Redirecting Based on Path**

```bash
frontend http_front
    bind *:80
    acl is_old_path path_beg /old
    http-request redirect location /new if is_old_path
    default_backend http_back
```

**Example: Routing Based on HTTP Header**

```bash
frontend http_front
    bind *:80
    acl is_mobile hdr_sub(User-Agent) Mobile
    use_backend mobile_back if is_mobile
    default_backend http_back
```

**Complex Conditions** You can combine multiple ACLs using logical operators (and, or, !). For instance:

**Example: Combining ACLs**

```bash
frontend http_front
    bind *:80
    acl is_admin src 192.168.1.100
    acl is_post method POST
    http-request deny if is_admin !is_post
    default_backend http_back
```

**Defining Backends and Using ACLs** ACLs are often used to route traffic to different backends based on the conditions.

**Example: Routing to Different Backends**

```bash
frontend http_front
    bind *:80
    acl is_static path_beg /static
    acl is_api path_beg /api
    use_backend static_back if is_static
    use_backend api_back if is_api
    default_backend http_back

backend static_back
    server static1 192.168.1.1:80 check
    server static2 192.168.1.2:80 check

backend api_back
    server api1 192.168.2.1:80 check
    server api2 192.168.2.2:80 check

backend http_back
    server web1 192.168.3.1:80 check
    server web2 192.168.3.2:80 check
```

**Example: Advanced Configuration with ACLs and Conditions**

```bash
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

defaults
    log global
    option httplog
    option dontlognull
    timeout connect 5000ms
    timeout client  50000ms
    timeout server  50000ms

frontend http_front
    bind *:80
    # Define ACLs
    acl is_admin src 192.168.1.100
    acl is_static path_beg /static
    acl is_api path_beg /api
    acl is_get method GET
    acl is_post method POST
    acl has_auth_token hdr_sub(Authorization) Bearer

    # Apply ACLs
    http-request deny if !is_admin has_auth_token
    http-request redirect location /new_static if is_static
    use_backend static_back if is_static
    use_backend api_back if is_api
    default_backend http_back

backend static_back
    balance roundrobin
    server static1 192.168.1.1:80 check
    server static2 192.168.1.2:80 check

backend api_back
    balance leastconn
    option httpchk GET /health
    http-check expect status 200
    server api1 192.168.2.1:80 check
    server api2 192.168.2.2:80 check

backend http_back
    balance roundrobin
    server web1 192.168.3.1:80 check
    server web2 192.168.3.2:80 check

listen stats
    bind *:8404
    mode http
    stats enable
    stats uri /haproxy?stats
    stats refresh 10s
    stats show-node
    stats auth admin:password
    stats admin if LOCALHOST
```

**Common ACL Options**

  **1.hdr (Header):**
    Matches an HTTP header.
    Example: Match requests with a specific User-Agent header.
```bash
acl is_chrome hdr(User-Agent) -i Mozilla
use_backend chrome_backend if is_chrome
```

  **2.hdr_beg (Header Begins With)**
    Matches if an HTTP header starts with a specified string.
    Example: Match requests where the Host header begins with admin.
```bash
acl is_admin hdr_beg(Host) -i admin
use_backend admin_backend if is_admin
```

  **3.hdr_end (Header Ends With)**
    Matches if an HTTP header ends with a specified string.
    Example: Match requests where the Host header ends with .example.com.
```bash
acl is_example_domain hdr_end(Host) -i .example.com
use_backend example_backend if is_example_domain
```

  **4.hdr_sub (Header Contains Substring)**
    Matches if an HTTP header contains a specific substring.
    Example: Match requests with a Referer header that contains example.
```bash
acl is_example_referer hdr_sub(Referer) -i example
use_backend example_referer_backend if is_example_referer
```

  **5.path (Request Path)**
    Matches based on the request URL path.
    Example: Match requests with a path starting with /api.
```bash
acl is_api path_beg /api
use_backend api_backend if is_api
```

  **6.path_beg (Path Begins With)**
    Matches if the request path begins with a specific string.
    Example: Match requests where the path starts with /images.
```bash
acl is_images path_beg /images
use_backend images_backend if is_images
```

  **7.path_end (Path Ends With)**
    Matches if the request path ends with a specific string.
    Example: Match requests where the path ends with .jpg.
```bash
acl is_jpg path_end .jpg
use_backend jpg_backend if is_jpg
```

  **8.path_reg (Path Matches Regex)**
    Matches if the request path matches a regular expression.
    Example: Match requests where the path contains numbers.
```bash
acl has_numbers path_reg -i [0-9]
use_backend numbers_backend if has_numbers
```

  **9.src (Source IP Address)**
    Matches based on the client’s source IP address.
    Example: Match requests from the IP range 192.168.1.0/24.
```bash
acl is_internal src 192.168.1.0/24
use_backend internal_backend if is_internal
```

  **10.dst (Destination IP Address)**
    Matches based on the destination IP address (useful in multi-IP setups).
    Example: Match requests directed to a specific IP.
```bash
acl is_specific_ip dst 192.168.1.10
use_backend specific_ip_backend if is_specific_ip
```

  **11.req_ssl_sni (SSL SNI)**
    Matches based on the Server Name Indication (SNI) in an SSL request.
    Example: Match requests for app1.example.com.
```bash
acl is_app1 req.ssl_sni -i app1.example.com
use_backend app1_backend if is_app1
```

  **12.ssl_fc (SSL Frontend Connection)**
    Matches if the frontend connection is using SSL.
    Example: Match requests that arrive over HTTPS.
```bash
acl is_https ssl_fc
use_backend https_backend if is_https
```

  **13.ssl_fc_sni (SSL Frontend SNI)**
    Matches based on the SNI in an SSL frontend connection.
    Example: Match requests for secure.example.com.
```bash
acl is_secure req.ssl_sni -i secure.example.com
use_backend secure_backend if is_secure
```

  **14.method (HTTP Method)**
    Matches based on the HTTP method (GET, POST, etc.).
    Example: Match requests that use the POST method.
```bash
acl is_post method POST
use_backend post_backend if is_post
```

  **15.req_len (Request Length)**
    Matches based on the size of the request.
    Example: Match requests larger than 100KB.
```bash
acl large_request req_len gt 100000
use_backend large_request_backend if large_request
```

  **16.cookie (HTTP Cookie)**
    Matches based on a specific HTTP cookie value.
    Example: Match requests where the session_id cookie is abc123.
```bash
acl valid_session cookie(session_id) -i abc123
use_backend session_backend if valid_session
```

  **17.req_fhdr (First Header)**
    Matches based on the first occurrence of a specific header.
    Example: Match the first X-Forwarded-For header value.
```bash
acl first_xff req.fhdr(X-Forwarded-For) -m found
use_backend xff_backend if first_xff
```

  **18.req_rdp_cookie (RDP Cookie)**
    Matches based on a specific RDP cookie.
    Example: Match RDP requests with a specific cookie.
```bash
acl rdp_cookie_present req_rdp_cookie mstshash -m found
use_backend rdp_backend if rdp_cookie_present
```

Example HAProxy Configuration with ACLs
Here's a sample configuration that uses multiple ACLs to route traffic:
```bash
haproxy
Copy code
frontend http_front
    bind *:80

    # ACLs
    acl is_api path_beg /api
    acl is_images path_beg /images
    acl is_jpg path_end .jpg
    acl is_chrome hdr_sub(User-Agent) Chrome
    acl is_internal src 192.168.1.0/24
    acl is_post method POST
    acl is_app1 req.ssl_sni -i app1.example.com
    acl large_request req_len gt 100000

    # Routing decisions based on ACLs
    use_backend api_backend if is_api
    use_backend images_backend if is_images
    use_backend jpg_backend if is_jpg
    use_backend chrome_backend if is_chrome
    use_backend internal_backend if is_internal
    use_backend post_backend if is_post
    use_backend app1_backend if is_app1
    use_backend large_request_backend if large_request

backend api_backend
    server api_server 192.168.1.101:80

backend images_backend
    server images_server 192.168.1.102:80

backend jpg_backend
    server jpg_server 192.168.1.103:80

backend chrome_backend
    server chrome_server 192.168.1.104:80

backend internal_backend
    server internal_server 192.168.1.105:80

backend post_backend
    server post_server 192.168.1.106:80

backend app1_backend
    server app1_server 192.168.1.107:80

backend large_request_backend
    server large_request_server 192.168.1.108:80
```

## Content Switching Configuration

Content switching typically involves defining Access Control Lists (ACLs) and using those ACLs to determine the appropriate backend for each request.

**Example: Basic Content Switching**
Suppose you have a website with static content, an API, and a main application. You want to route requests based on the URL path:
    - **Static content** goes to `static_back`.
    - **API requests** go to `api_back`.
    - **Other requests** go to `app_back`.
Here’s how you can configure HAProxy to achieve this:

```bash
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

defaults
    log global
    option httplog
    option dontlognull
    timeout connect 5000ms
    timeout client  50000ms
    timeout server  50000ms

frontend http_front
    bind *:80

    # Define ACLs
    acl is_static path_beg /static
    acl is_api path_beg /api

    # Use backends based on ACLs
    use_backend static_back if is_static
    use_backend api_back if is_api
    default_backend app_back

backend static_back
    server static1 192.168.1.1:80 check
    server static2 192.168.1.2:80 check

backend api_back
    server api1 192.168.2.1:80 check
    server api2 192.168.2.2:80 check

backend app_back
    server app1 192.168.3.1:80 check
    server app2 192.168.3.2:80 check

listen stats
    bind *:8404
    mode http
    stats enable
    stats uri /haproxy?stats
    stats refresh 10s
    stats show-node
    stats auth admin:password
    stats admin if LOCALHOST
```

**Advanced Content Switching**
You can define more complex content switching rules by using multiple ACLs and combining them with logical operators.

**Example: Combining Multiple Criteria**
In this example, requests are routed based on both the URL path and the presence of a specific header.

```bash
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

defaults
    log global
    option httplog
    option dontlognull
    timeout connect 5000ms
    timeout client  50000ms
    timeout server  50000ms

frontend http_front
    bind *:80

    # Define ACLs
    acl is_static path_beg /static
    acl is_api path_beg /api
    acl has_auth_token hdr_sub(Authorization) Bearer

    # Use backends based on combined ACLs
    use_backend static_back if is_static
    use_backend api_back if is_api !has_auth_token
    use_backend secure_api_back if is_api has_auth_token
    default_backend app_back

backend static_back
    server static1 192.168.1.1:80 check
    server static2 192.168.1.2:80 check

backend api_back
    server api1 192.168.2.1:80 check
    server api2 192.168.2.2:80 check

backend secure_api_back
    server secure_api1 192.168.2.3:80 check
    server secure_api2 192.168.2.4:80 check

backend app_back
    server app1 192.168.3.1:80 check
    server app2 192.168.3.2:80 check

listen stats
    bind *:8404
    mode http
    stats enable
    stats uri /haproxy?stats
    stats refresh 10s
    stats show-node
    stats auth admin:password
    stats admin if LOCALHOST
```

**Content Switching with SSL Termination**
If you need to perform content switching on an HTTPS frontend, you must configure SSL termination.

```bash
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon
    tune.ssl.default-dh-param 2048

defaults
    log global
    option httplog
    option dontlognull
    timeout connect 5000ms
    timeout client  50000ms
    timeout server  50000ms

frontend https_front
    bind *:443 ssl crt /etc/ssl/private/haproxy.pem
    redirect scheme https code 301 if !{ ssl_fc }

    # Define ACLs
    acl is_static path_beg /static
    acl is_api path_beg /api
    acl has_auth_token hdr_sub(Authorization) Bearer

    # Use backends based on combined ACLs
    use_backend static_back if is_static
    use_backend api_back if is_api !has_auth_token
    use_backend secure_api_back if is_api has_auth_token
    default_backend app_back

backend static_back
    server static1 192.168.1.1:80 check
    server static2 192.168.1.2:80 check

backend api_back
    server api1 192.168.2.1:80 check
    server api2 192.168.2.2:80 check

backend secure_api_back
    server secure_api1 192.168.2.3:80 check
    server secure_api2 192.168.2.4:80 check

backend app_back
    server app1 192.168.3.1:80 check
    server app2 192.168.3.2:80 check

listen stats
    bind *:8404
    mode http
    stats enable
    stats uri /haproxy?stats
    stats refresh 10s
    stats show-node
    stats auth admin:password
    stats admin if LOCALHOST
```

## HAProxy HTTP Redirection & Rewriting​
HAProxy provides powerful features for HTTP rewriting and redirection, enabling you to modify URLs and redirect traffic based on specific conditions. These features are essential for tasks such as URL normalization, security enhancements, and user-friendly redirects.

**Example: Basic HTTP to HTTPS Redirection**Redirect all HTTP traffic to HTTPS:

```bash
frontend http_front
    bind *:80
    redirect scheme https code 301 if !{ ssl_fc }
```
**Example: Redirect Based on URL Path**Redirect requests from /oldpath to /newpath:

```bash
frontend http_front
    bind *:80
    acl is_oldpath path_beg /oldpath
    http-request redirect location /newpath if is_oldpath
    default_backend http_back
```

**Example: Basic URL Rewriting**Rewrite URLs starting with /oldpath to /newpath:

```bash
frontend http_front
    bind *:80
    acl is_oldpath path_beg /oldpath
    http-request set-path /newpath%[path,regsub(^/oldpath,/)]
    default_backend http_back
```

**Example: Rewriting with Query Parameters**Rewrite URL and add a query parameter:

```bash
frontend http_front
    bind *:80
    acl is_oldpath path_beg /oldpath
    http-request set-query newparam=value if is_oldpath
    http-request set-path /newpath%[path,regsub(^/oldpath,/)]
    default_backend http_back
```

**Advanced Examples**

**Example: Combining Redirection and Rewriting**Redirect traffic from HTTP to HTTPS and rewrite the URL path:

```bash
frontend http_front
    bind *:80
    redirect scheme https code 301 if !{ ssl_fc }

frontend https_front
    bind *:443 ssl crt /etc/ssl/private/haproxy.pem
    acl is_oldpath path_beg /oldpath
    http-request set-path /newpath%[path,regsub(^/oldpath,/)] if is_oldpath
    default_backend https_back

backend https_back
    server web1 192.168.1.1:443 check ssl verify none
    server web2 192.168.1.2:443 check ssl verify none
```

**Example: Conditional Redirection Based on Header**Redirect requests with a specific header to a different domain:

```bash
frontend http_front
    bind *:80
    acl is_special_user hdr_sub(User-Agent) SpecialClient
    http-request redirect location https://special.example.com if is_special_user
    default_backend http_back
```

**URL Normalization** Normalize URLs by removing or modifying specific parts of the URL:

```bash
frontend http_front
    bind *:80
    # Remove trailing slash
    acl has_trailing_slash path_end /
    http-request set-path %[path,regsub(/$,)] if has_trailing_slash
    default_backend http_back
```

**Full Configuration Example**Combining various redirection and rewriting rules in a single configuration:

```bash
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

defaults
    log global
    option httplog
    option dontlognull
    timeout connect 5000ms
    timeout client  50000ms
    timeout server  50000ms

frontend http_front
    bind *:80
    redirect scheme https code 301 if !{ ssl_fc }

frontend https_front
    bind *:443 ssl crt /etc/ssl/private/haproxy.pem

    # ACLs for URL paths
    acl is_oldpath path_beg /oldpath
    acl is_special_user hdr_sub(User-Agent) SpecialClient

    # Redirection and Rewriting
    http-request redirect location https://special.example.com if is_special_user
    http-request set-path /newpath%[path,regsub(^/oldpath,/)] if is_oldpath

    # Normalize URLs
    acl has_trailing_slash path_end /
    http-request set-path %[path,regsub(/$,)] if has_trailing_slash

    default_backend https_back

backend https_back
    server web1 192.168.1.1:443 check ssl verify none
    server web2 192.168.1.2:443 check ssl verify none

listen stats
    bind *:8404
    mode http
    stats enable
    stats uri /haproxy?stats
    stats refresh 10s
    stats show-node
    stats auth admin:password
    stats admin if LOCALHOST
```

## HAProxy Global Configuration
```bash
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon
    maxconn 2000
    nbproc 4
    nbthread 2
    cpu-map auto:1-4 0-3
    timeout connect 5s
    timeout client 30s
    timeout server 30s
    tune.ssl.default-dh-param 2048
```