#!/bin/bash
# install_api.sh
# Instala Docker y ejecuta la API Flask como contenedor

# Actualizar paquetes e instalar Docker
sudo apt-get update -y
sudo apt-get install -y docker.io

# Habilitar y arrancar Docker
sudo systemctl enable docker
sudo systemctl start docker

# Eliminar contenedor existente si hay
sudo docker rm -f iot-api >/dev/null 2>&1 || true

# Descargar imagen de la API desde Docker Hub
sudo docker pull "${api_image}"

# Ejecutar contenedor de la API
# Puerto 5000: Flask API
# RABBITMQ_HOST: IP privada de RabbitMQ (inyectada por Terraform)
sudo docker run -d \
  --name iot-api \
  --restart unless-stopped \
  -p 5000:5000 \
  -e RABBITMQ_HOST="${rabbitmq_host}" \
  -e PYTHONUNBUFFERED=1 \
  "${api_image}"