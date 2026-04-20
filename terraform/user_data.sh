#!/bin/bash
# user_data.sh - Provisioning script for Ubuntu 22.04 LTS

set -e

# Actualizar sistema e instalar dependencias
apt-get update -y
apt-get install -y apt-transport-https ca-certificates curl software-properties-common git

# Instalar Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io

# Instalar Docker Compose (V2)
mkdir -p /usr/local/lib/docker/cli-plugins/
curl -SL https://github.com/docker/compose/releases/download/v2.24.5/docker-compose-linux-x86_64 -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# Habilitar Docker para el usuario ubuntu
usermod -aG docker ubuntu

# Clonar el repositorio
cd /home/ubuntu
# Nota: Se recomienda cambiar esta URL por la URL real del repositorio
git clone https://github.com/Jdavidruanob/aws-iot-backend-architecture.git
cd aws-iot-backend-architecture

# Levantar la infraestructura
docker compose up -d
