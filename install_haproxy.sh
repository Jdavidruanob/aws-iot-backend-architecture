#!/bin/bash
set -euxo pipefail

exec > >(tee /var/log/install-haproxy.log | logger -t install-haproxy -s 2>/dev/console) 2>&1

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y docker.io

systemctl enable docker
systemctl start docker

mkdir -p /opt/haproxy

cat > /opt/haproxy/haproxy.cfg <<EOF
global
    log stdout format raw local0

defaults
    log global
    mode http
    timeout connect 5s
    timeout client 50s
    timeout server 50s

frontend http-in
    bind *:80
    default_backend api_servers

backend api_servers
    balance roundrobin
    option httpchk GET /health
    server api1 ${api_server_1_ip}:5000 check
    server api2 ${api_server_2_ip}:5000 check
EOF

docker rm -f iot-haproxy >/dev/null 2>&1 || true

docker run -d \
  --name iot-haproxy \
  --restart unless-stopped \
  -p 80:80 \
  -v /opt/haproxy/haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro \
  haproxy:2.9
