#!/bin/bash
set -euxo pipefail

exec > >(tee /var/log/install-rabbitmq.log | logger -t install-rabbitmq -s 2>/dev/console) 2>&1

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y docker.io

systemctl enable docker
systemctl start docker

docker rm -f iot-rabbitmq >/dev/null 2>&1 || true

docker run -d \
  --name iot-rabbitmq \
  --restart unless-stopped \
  -p 5672:5672 \
  -p 15672:15672 \
  -e RABBITMQ_DEFAULT_USER=guest \
  -e RABBITMQ_DEFAULT_PASS=guest \
  rabbitmq:3-management
