<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [rds-relay-server](#rds-relay-server)
  - [Rename from "wstty-server"](#rename-from-wstty-server)
  - [Docker](#docker)
    - [Basic Usages](#basic-usages)
    - [Advanced Usages](#advanced-usages)
  - [Advanced Installation](#advanced-installation)
    - [User Management](#user-management)
    - [Websocket over TLS](#websocket-over-tls)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# rds-relay-server

WebSocket Relay Server for Remote Device Diagnosis

## Rename from "wstty-server"

[wstty-server](https://github.com/tic-tac-toe-io/wstty-server) was originally developed for embedded linux environment (running on the IoT gateway to manage many other IoT devices in the same subnet), so its codes are heavily dependent on [yapps](https://github.com/yagamy4680/yapps) and produce single bundle js file for execution with [browserify](http://browserify.org/). However, [yapps](https://github.com/yagamy4680/yapps) does not support cluster, which will be an obvious limitation to wstty-server at larger scale deployment. So, in the roadmap of wstty-server, we are planning to rewrite it from scratch by considering cloud native environment and scability since v2.0.

To align with v2.0 plan of wstty-server and our official service RDS (**Remote Diagnosis Service**) publish, we rename `wstty-server` to `rds-relay-server` and starts its first rollout version `v2.0.0`.


## Docker

Repository: https://hub.docker.com/r/tictactoe/rds-relay-server

### Basic Usages

Running `rds-relay-server` with Docker for one-time is quite simple:

```text
$ docker run --rm -p 6030:6030 --name rds-relay-server tictactoe/rds-relay-server:latest
```

Or, maybe run `rds-relay-server` as a background daemon:

```text
$ docker run -d -p 6030:6030 --name rds-relay-server tictactoe/rds-relay-server:latest
```


### Advanced Usages

The docker image supports to dump default YAML configuration, and run the daemon with the modified YAML configuration file. For example:

```text
$ docker run --rm tictactoe/rds-relay-server:latest config > YOUR_PATH/rds.yml
$
$ docker run \
    -d \
    -v YOUR_PATH/rds.yml:/tic/config/default.yml \
    -p 6030:6030 \
    --name rds-relay-server \
    tictactoe/rds-relay-server:latest
```


## Advanced Installation

### User Management

T.B.D.

### Websocket over TLS

wstty-server doesn't support websocket over TLS as builtin feature, but we recommend to configure [Nginx](https://www.nginx.com/) to support SSL/TLS Offloading to work with wstty-server. Here is sample nginx configuration:

```text
server {
  listen 443 ssl http2;
  server_name wstty.example.com;
  server_tokens off;

  # Certificates
  ssl_certificate         /etc/letsencrypt/live/example.com/fullchain.pem;
  ssl_certificate_key     /etc/letsencrypt/live/example.com/privkey.pem;
  ssl_trusted_certificate /etc/letsencrypt/live/example.com/fullchain.pem;

  # SSL
  ssl_session_timeout 1d;
  ssl_session_cache shared:SSL:50m;
  ssl_session_tickets off;

  # modern configuration
  ssl_protocols TLSv1.2;
  ssl_ciphers ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256;
  ssl_prefer_server_ciphers on;

  # OCSP Stapling
  ssl_stapling on;
  ssl_stapling_verify on;
  resolver 1.1.1.1 1.0.0.1 8.8.8.8 8.8.4.4 208.67.222.222 208.67.220.220 valid=60s;
  resolver_timeout 2s;

  # individual nginx logs for this redmine vhost
  access_log  /var/log/nginx/wstty-example-com.access.log;
  error_log   /var/log/nginx/wstty-example-com.error.log;

  ## If a file, which is not found in the root folder is requested,
  ## then the proxy pass the request to the upsteam (redmine unicorn).
  location / {
    proxy_set_header    Host                $http_host;
    proxy_set_header    X-Real-IP           $remote_addr;
    proxy_set_header    X-Forwarded-Ssl     on;
    proxy_set_header    X-Forwarded-For     $proxy_add_x_forwarded_for;
    proxy_set_header    X-Forwarded-Proto   https;
    proxy_set_header    X-Frame-Options     SAMEORIGIN;

    proxy_http_version  1.1;
    proxy_set_header  Upgrade       $http_upgrade;
    proxy_set_header  Connection      "upgrade";

    proxy_pass http://127.0.0.1:6030;
  }

  error_page 500 /500.html;
}

server {
  listen 80;
  server_name wstty.example.com;
  return 301 https://$server_name$request_uri;
}
```

Above configuration assumes:

- The site for wstty-server is https://wstty.example.com
- You've applied wildcard SSL certificate for `example.com` domain from Let's Encrypt, and put those certificates at `/etc/letsencrypt/live/example.com`
- wstty-server and nginx are running in the same machine, so `proxy_pass http://127.0.0.1:6030`

Store above configuration file at `/etc/nginx/conf.d/wstty-example-com.conf`, and force Nginx to reload settings. Then open browser to visit https://wstty.example.com/tty to enjoy Web TTY with default account `test1` (password is the same).

Reference studies:

- [SSL/TLS Offloading, Encryption, and Certificates with NGINX and NGINX Plus](https://www.nginx.com/blog/nginx-ssl/)
- [Generate Wildcard SSL certificate using Let’s Encrypt/Certbot](https://medium.com/@saurabh6790/generate-wildcard-ssl-certificate-using-lets-encrypt-certbot-273e432794d7)
- [Nginx Beginner’s Guide](http://nginx.org/en/docs/beginners_guide.html)


## TODO

Refer to [TODO.md](./docs/TODO.md).
