#!/bin/bash
# install_worker.sh
# Instala Docker y ejecuta el Worker como contenedor

# Actualizar paquetes e instalar Docker
sudo apt-get update -y
sudo apt-get install -y docker.io

# Habilitar y arrancar Docker
sudo systemctl enable docker
sudo systemctl start docker

# Eliminar contenedor existente si hay
sudo docker rm -f iot-worker >/dev/null 2>&1 || true

# Descargar imagen del Worker desde Docker Hub
sudo docker pull "${worker_image}"

# Ejecutar contenedor del Worker
# RABBITMQ_HOST: IP privada de RabbitMQ (inyectada por Terraform)
# POSTGRES_HOST: IP privada de PostgreSQL (inyectada por Terraform)
sudo docker run -d \
  --name iot-worker \
  --restart unless-stopped \
  -e RABBITMQ_HOST="${rabbitmq_host}" \
  -e POSTGRES_HOST="${postgres_host}" \
  -e PYTHONUNBUFFERED=1 \
  "${worker_image}"