#!/bin/bash
# install_rabbitmq.sh
# Instala Docker y ejecuta RabbitMQ como contenedor

# Actualizar paquetes e instalar Docker
sudo apt-get update -y
sudo apt-get install -y docker.io

# Habilitar y arrancar Docker
sudo systemctl enable docker
sudo systemctl start docker

# Eliminar contenedor existente si hay
sudo docker rm -f iot-rabbitmq >/dev/null 2>&1 || true

# Ejecutar contenedor RabbitMQ
# Puerto 5672: AMQP (comunicacion interna)
# Puerto 15672: UI de administracion
sudo docker run -d \
  --name iot-rabbitmq \
  --restart unless-stopped \
  -p 5672:5672 \
  -p 15672:15672 \
  -e RABBITMQ_DEFAULT_USER=guest \
  -e RABBITMQ_DEFAULT_PASS=guest \
  rabbitmq:3-management