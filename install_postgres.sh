#!/bin/bash
set -euxo pipefail

exec > >(tee /var/log/install-postgres.log | logger -t install-postgres -s 2>/dev/console) 2>&1

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y docker.io

systemctl enable docker
systemctl start docker

docker rm -f iot-postgres >/dev/null 2>&1 || true
docker volume create iot-postgres-data >/dev/null

docker run -d \
  --name iot-postgres \
  --restart unless-stopped \
  -p 5432:5432 \
  -e POSTGRES_DB=iot_project \
  -e POSTGRES_USER=admin \
  -e POSTGRES_PASSWORD=adminpassword \
  -v iot-postgres-data:/var/lib/postgresql/data \
  postgres:15
