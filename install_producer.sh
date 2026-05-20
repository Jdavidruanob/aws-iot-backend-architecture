#!/bin/bash
set -euxo pipefail

exec > >(tee /var/log/install-producer.log | logger -t install-producer -s 2>/dev/console) 2>&1

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y docker.io

systemctl enable docker
systemctl start docker

docker rm -f iot-producer >/dev/null 2>&1 || true
docker pull "${producer_image}"

docker run -d \
  --name iot-producer \
  --restart unless-stopped \
  -e API_URL="${api_url}" \
  -e PYTHONUNBUFFERED=1 \
  "${producer_image}"
