#!/bin/bash
# install_producer.sh
# Instala Docker y ejecuta el Producer (simulador de sensores IoT)

# Actualizar paquetes e instalar Docker
sudo apt-get update -y
sudo apt-get install -y docker.io

# Habilitar y arrancar Docker
sudo systemctl enable docker
sudo systemctl start docker

# Eliminar contenedor existente si hay
sudo docker rm -f iot-producer >/dev/null 2>&1 || true

# Descargar imagen del Producer desde Docker Hub
sudo docker pull "${producer_image}"

# Ejecutar contenedor del Producer
# API_URL: URL publica del HAProxy (inyectada por Terraform)
# El Producer envia datos de sensores a esta URL
sudo docker run -d \
  --name iot-producer \
  --restart unless-stopped \
  -e API_URL="${api_url}" \
  -e PYTHONUNBUFFERED=1 \
  "${producer_image}"