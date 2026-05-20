#!/bin/bash
set -euxo pipefail

exec > >(tee /var/log/install-worker.log | logger -t install-worker -s 2>/dev/console) 2>&1

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y docker.io

systemctl enable docker
systemctl start docker

docker rm -f iot-worker >/dev/null 2>&1 || true
docker pull "${worker_image}"

docker run -d \
  --name iot-worker \
  --restart unless-stopped \
  -e RABBITMQ_HOST="${rabbitmq_host}" \
  -e POSTGRES_HOST="${postgres_host}" \
  -e PYTHONUNBUFFERED=1 \
  "${worker_image}"
