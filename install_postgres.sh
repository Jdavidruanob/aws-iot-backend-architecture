#!/bin/bash
# install_postgres.sh
# Instala Docker y ejecuta PostgreSQL como contenedor

# Actualizar paquetes e instalar Docker
sudo apt-get update -y
sudo apt-get install -y docker.io

# Habilitar y arrancar Docker
sudo systemctl enable docker
sudo systemctl start docker

# Eliminar contenedor existente si hay
sudo docker rm -f iot-postgres >/dev/null 2>&1 || true

# Crear volumen Docker para persistencia de datos
sudo docker volume create iot-postgres-data >/dev/null

# Ejecutar contenedor PostgreSQL
# Puerto 5432: PostgreSQL
# Variables de entorno para crear DB, usuario y contrasena
sudo docker run -d \
  --name iot-postgres \
  --restart unless-stopped \
  -p 5432:5432 \
  -e POSTGRES_DB=iot_project \
  -e POSTGRES_USER=admin \
  -e POSTGRES_PASSWORD=adminpassword \
  -v iot-postgres-data:/var/lib/postgresql/data \
  postgres:15