#!/bin/bash
set -euxo pipefail

exec > >(tee /var/log/install-api.log | logger -t install-api -s 2>/dev/console) 2>&1

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y docker.io

systemctl enable docker
systemctl start docker

docker rm -f iot-api >/dev/null 2>&1 || true
docker pull "${api_image}"

docker run -d \
  --name iot-api \
  --restart unless-stopped \
  -p 5000:5000 \
  -e RABBITMQ_HOST="${rabbitmq_host}" \
  -e PYTHONUNBUFFERED=1 \
  "${api_image}"
