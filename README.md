# AWS IoT Backend Architecture

**Actividad académica del curso de IoT (Internet of Things)**

Sistema de backend asíncrono para ingestión de datos IoT con arquitectura distribuida en AWS. Desplegado en 7 instancias EC2 con balanceo de carga, colas de mensajes y base de datos.

## Tabla de Contenidos

- [Descripción](#descripción)
- [Arquitectura](#arquitectura)
- [Requisitos](#requisitos)
- [Despliegue en AWS](#despliegue-en-aws)
- [API Endpoints](#api-endpoints)
- [Scripts de Instalación](#scripts-de-instalación)
- [Pruebas](#pruebas)
- [Base de Datos](#base-de-datos)

---

## Descripción

Este proyecto implementa una pipeline asíncrona para procesar datos de sensores IoT:

1. **Producer** - Simula sensores IoT enviando datos constantemente
2. **HAProxy** - Balanceador de carga en puerto 80
3. **API Servers (x2)** - Reciben datos y los encolan en RabbitMQ (respuesta 202 inmediata)
4. **RabbitMQ** - Message broker con cola `iot_tasks_queue`
5. **Worker** - Consume la cola y almacena datos en PostgreSQL
6. **PostgreSQL** - Almacena los datos de sensores

El cliente recibe un **TaskId (UUID)** para tracking asíncrono.

---

## Arquitectura

```
                     ┌─────────────────────────────────┐
                     │         AWS Cloud               │
                     │                                 │
    ┌──────────┐     │   ┌─────────────────────────┐   │
    │ Producer │─────┼──▶│    HAProxy EC2          │   │
    │  EC2     │     │   │    Puerto 80 (LB)       │   │
    └──────────┘     │   └───────────┬─────────────┘   │
                     │               │                  │
                     │   ┌──────────┴──────────┐       │
                     │   ▼                     ▼       │
                     │ ┌──────────┐    ┌──────────┐   │
                     │ │ API EC2-1│    │ API EC2-2│   │
                     │ │Puerto 5000│    │Puerto 5000│   │
                     │ └──────┬───┘    └──────┬───┘   │
                     │        │               │       │
                     │        └───────┬───────┘       │
                     │                ▼               │
                     │   ┌────────────────────┐        │
                     │   │   RabbitMQ EC2     │        │
                     │   │   Puerto 5672      │        │
                     │   └─────────┬──────────┘        │
                     │             │                   │
                     │   ┌─────────┴──────────┐        │
                     │   ▼                   ▼        │
                     │ ┌──────────┐    ┌──────────┐  │
                     │ │ Worker   │    │PostgreSQL│  │
                     │ │ EC2      │    │ EC2      │  │
                     │ └──────────┘    │Puerto 5432│  │
                     │                 └──────────┘   │
                     └─────────────────────────────────┘
```

### Servicios y Puertos

| Servicio | Puerto | Descripción | SSM Parameter |
|----------|--------|-------------|---------------|
| HAProxy | 80 | Load Balancer | `/iot/dev/haproxy/ip` |
| API Server 1 | 5000 | Flask API (AZ1) | `/iot/dev/api-1/ip` |
| API Server 2 | 5000 | Flask API (AZ2) | `/iot/dev/api-2/ip` |
| RabbitMQ | 5672, 15672 | Message Broker | `/iot/dev/rabbitmq/ip` |
| Worker | - | Consumidor | `/iot/dev/worker/ip` |
| PostgreSQL | 5432 | Base de datos | `/iot/dev/postgres/ip` |
| Producer | - | Simulador IoT | `/iot/dev/producer/ip` |

---

## Requisitos

### Para desplegar en AWS

- Cuenta de AWS con permisos para crear EC2s, VPC, Security Groups
- Terraform instalado o usar el contenedor del Learner Lab
- Docker Hub con imágenes publicadas de API, Worker y Producer

### Para ejecutar pruebas

- SSH key (`iot_key.pem`)
- `curl`, `python3`, `ssh`
- Credenciales de AWS configuradas

---

## Despliegue en AWS

### Estrategia de despliegue

- **Sistema operativo:** Ubuntu Server 24.04 LTS
- **Infraestructura:** Terraform
- **Artefactos de aplicación:** imágenes Docker Hub pre-built
- **Conexiones internas:** Terraform inyecta IPs privadas en los contenedores via `user_data`
- **SSM Parameter Store:** Terraform publica IPs para verificación/debug

### Imágenes requeridas en Docker Hub

El proyecto usa estas imágenes (configuradas en `terraform/variables.tf`):

```
jdavidruanob/aws-iot-api:latest
jdavidruanob/aws-iot-worker:latest
jdavidruanob/aws-iot-producer:latest
```

Si necesitas reconstruirlas:

```bash
# API
docker build -t jdavidruanob/aws-iot-api:latest ./api
docker push jdavidruanob/aws-iot-api:latest

# Worker
docker build -t jdavidruanob/aws-iot-worker:latest ./worker
docker push jdavidruanob/aws-iot-worker:latest

# Producer
docker build -t jdavidruanob/aws-iot-producer:latest ./simulator
docker push jdavidruanob/aws-iot-producer:latest
```

### Estructura de Terraform

```
terraform/
├── providers.tf         # Proveedor AWS
├── variables.tf         # Variables (VPC, AMI, imágenes)
├── main.tf             # 7 EC2s + SSM Parameters
├── security_groups.tf  # Firewalls
└── outputs.tf          # IPs públicas de salida
```

### Pasos para desplegar

```bash
# 1. Ir al directorio de Terraform
cd terraform

# 2. Inicializar Terraform
terraform init

# 3. Ver plan de cambios
terraform plan

# 4. Aplicar cambios (escribir "yes")
terraform apply

# 5. Ver IPs de los servicios
terraform output
```

### Credenciales de acceso

| Servicio | Usuario | Contraseña |
|----------|---------|------------|
| RabbitMQ UI | guest | guest |
| PostgreSQL | admin | adminpassword |

---

## API Endpoints

### POST /api/sensor-data

Recibe datos de sensores IoT.

**Request:**
```json
{
  "sensor_id": "Sensor_Temp_Cocina",
  "valor": 25.5
}
```

**Response (202 Accepted):**
```json
{
  "message": "Dato recibido",
  "TaskId": "abc123-def456-..."
}
```

### GET /health

Health check para HAProxy.

**Response:**
```json
{
  "status": "healthy"
}
```

---

## Scripts de Instalación

Cada servicio tiene su propio script (`install_*.sh`) que se ejecuta en el `user_data` de la EC2:

| Script | Descripción |
|--------|-------------|
| `install_haproxy.sh` | HAProxy como contenedor Docker |
| `install_api.sh` | API Flask (docker pull + run) |
| `install_rabbitmq.sh` | RabbitMQ en contenedor Docker |
| `install_worker.sh` | Worker (docker pull + run) |
| `install_postgres.sh` | PostgreSQL en contenedor Docker |
| `install_producer.sh` | Producer (docker pull + run) |

### Comportamiento

1. Instala Docker
2. Habilita e inicia Docker
3. Descarga imagen de Docker Hub (si aplica)
4. Ejecuta el contenedor con variables de entorno inyectadas por Terraform

---

## Pruebas

### Smoke Test Automático

El script `scripts/run_aws_smoke_tests.sh` valida todo el sistema:

```bash
SSH_KEY=./iot_key.pem ./scripts/run_aws_smoke_tests.sh
```

Si Terraform no está disponible localmente, pasa las IPs manualmente:

```bash
SSH_KEY=./iot_key.pem \
HAPROXY_PUBLIC_IP=54.237.160.6 \
HAPROXY_URL=http://54.237.160.6/api/sensor-data \
RABBITMQ_PUBLIC_IP=13.222.122.42 \
WORKER_PUBLIC_IP=98.92.190.96 \
PRODUCER_PUBLIC_IP=44.201.55.237 \
POSTGRES_PUBLIC_IP=44.198.58.211 \
./scripts/run_aws_smoke_tests.sh
```

### Qué valida el smoke test

1. HAProxy responde `/health`
2. API acepta mensajes POST y devuelve TaskId
3. RabbitMQ UI accesible en puerto 15672
4. Worker corriendo e insertando en PostgreSQL
5. Producer enviando datos
6. HAProxy configurado con roundrobin y 2 APIs
7. PostgreSQL con registros en `sensor_data`

### Verificación manual

```bash
# Health check
curl http://<haproxy-ip>/health

# Enviar dato manual
curl -X POST http://<haproxy-ip>/api/sensor-data \
  -H "Content-Type: application/json" \
  -d '{"sensor_id":"TestSensor","valor":28.7}'

# Ver RabbitMQ UI
# http://<rabbitmq-ip>:15672 (guest/guest)
```

### Ver logs de servicios

```bash
# Worker
ssh -i iot_key.pem ubuntu@<worker-ip> "sudo docker logs iot-worker --tail 50"

# Producer
ssh -i iot_key.pem ubuntu@<producer-ip> "sudo docker logs iot-producer --tail 50"

# HAProxy
ssh -i iot_key.pem ubuntu@<haproxy-ip> "sudo docker logs iot-haproxy --tail 50"
```

---

## Base de Datos

### Tabla sensor_data

```sql
CREATE TABLE sensor_data (
    id SERIAL PRIMARY KEY,
    task_id VARCHAR(255) UNIQUE NOT NULL,
    sensor_id VARCHAR(50) NOT NULL,
    valor FLOAT NOT NULL,
    status VARCHAR(20) NOT NULL,
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Consultar datos

Desde el Worker (usando docker run con psql):

```bash
ssh -i iot_key.pem ubuntu@<worker-ip>

# Obtener IP de PostgreSQL
echo $POSTGRES_HOST

# Consultar datos
sudo docker run --rm -e PGPASSWORD=adminpassword postgres:15 psql \
  -h $POSTGRES_HOST -U admin -d iot_project -c "SELECT * FROM sensor_data LIMIT 10;"
```

---

## Archivos del Proyecto

```
aws-iot-backend-architecture/
├── api/                      # API Flask
│   ├── main.py              # Endpoint /api/sensor-data, /health
│   ├── Dockerfile
│   └── requirements.txt
├── worker/                   # Worker consumidor
│   ├── worker.py            # consume RabbitMQ, inserta en PostgreSQL
│   ├── Dockerfile
│   └── requirements.txt
├── simulator/                # Simulador de sensores
│   ├── sensor_mock.py       # Genera datos de sensores
│   ├── Dockerfile
│   └── requirements.txt
├── terraform/                 # Infraestructura AWS
│   ├── main.tf              # 7 EC2s + SSM Parameters
│   ├── variables.tf
│   ├── security_groups.tf
│   └── outputs.tf
├── scripts/
│   └── run_aws_smoke_tests.sh  # Smoke test automático
├── install_*.sh              # Scripts para EC2s (user_data)
├── get_parameter.py         # Helper SSM (debug)
├── pruebas.md               # Guía de pruebas
├── README.md                # Este archivo
└── SPEC.md                  # Especificación técnica
```