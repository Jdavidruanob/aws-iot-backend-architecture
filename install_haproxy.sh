#!/bin/bash
# install_haproxy.sh
# Instala Docker y ejecuta HAProxy como balanceador de carga

# Actualizar paquetes e instalar Docker
sudo apt-get update -y
sudo apt-get install -y docker.io

# Habilitar y arrancar Docker
sudo systemctl enable docker
sudo systemctl start docker

# Crear directorio para la configuracion de HAProxy
sudo mkdir -p /opt/haproxy

# Escribir archivo de configuracion de HAProxy
# Las IPs de las APIs son inyectadas por Terraform via templatefile
cat > /opt/haproxy/haproxy.cfg <<EOF
global
    log stdout format raw local0

defaults
    log global
    mode http
    timeout connect 5s
    timeout client 50s
    timeout server 50s

frontend http-in
    bind *:80
    default_backend api_servers

backend api_servers
    balance roundrobin
    option httpchk GET /health
    server api1 ${api_server_1_ip}:5000 check
    server api2 ${api_server_2_ip}:5000 check
EOF

# Eliminar contenedor existente si hay
sudo docker rm -f iot-haproxy >/dev/null 2>&1 || true

# Ejecutar contenedor HAProxy
# Monta el archivo de configuracion dentro del contenedor (read-only)
sudo docker run -d \
  --name iot-haproxy \
  --restart unless-stopped \
  -p 80:80 \
  -v /opt/haproxy/haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro \
  haproxy:2.9