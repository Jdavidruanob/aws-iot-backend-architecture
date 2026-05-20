# AWS IoT Async Data Pipeline

Sistema de backend asíncrono para ingestión de datos IoT con arquitectura distribuida en AWS.

## Tabla de Contenidos

- [Descripción](#descripción)
- [Arquitectura](#arquitectura)
- [Modes de Uso](#modos-de-uso)
- [Desarrollo Local](#desarrollo-local)
- [Despliegue en AWS](#despliegue-en-aws)
- [API Endpoints](#api-endpoints)
- [Scripts de Instalación](#scripts-de-instalación)
- [Pruebas](#pruebas)

---

## Descripción

Este proyecto implementa una pipeline asíncrona para procesar datos de sensores IoT:

1. **Productor** envía datos de sensores
2. **HAProxy** balancea entre múltiples APIs
3. **API Flask** recibe datos y los encola en RabbitMQ (respuesta 202 inmediata)
4. **Worker** consume la cola y almacena en PostgreSQL
5. Cliente recibe **TaskId** para consulta posterior

---

## Arquitectura

```
                    ┌─────────────────────────────────┐
                    │         AWS Cloud               │
                    │                                 │
   ┌──────────┐     │   ┌─────────────────────────┐   │
   │ Producer │─────┼──▶│    HAProxy EC2          │   │
   │  EC2     │     │   │    Puerto 80 (LB)        │   │
   └──────────┘     │   └───────────┬─────────────┘   │
                    │               │                  │
                    │   ┌──────────┴──────────┐       │
                    │   ▼                     ▼       │
                    │ ┌──────────┐    ┌──────────┐   │
                    │ │ API EC2-1│    │ API EC2-2│   │
                    │ │Puerto 5000    │Puerto 5000│   │
                    │ └──────┬───┘    └──────┬───┘   │
                    │        │               │       │
                    │        └───────┬───────┘       │
                    │                ▼               │
                    │   ┌────────────────────┐      │
                    │   │   RabbitMQ EC2     │      │
                    │   │   Puerto 5672      │      │
                    │   └─────────┬──────────┘      │
                    │             │                  │
                    │   ┌─────────┴──────────┐       │
                    │   ▼                   ▼       │
                    │ ┌──────────┐    ┌──────────┐ │
                    │ │ Worker   │    │PostgreSQL│ │
                    │ │ EC2      │    │ EC2      │ │
                    │ └──────────┘    │Puerto 5432│ │
                    │                 └──────────┘   │
                    └─────────────────────────────────┘
```

### Servicios

| Servicio | Puerto | SSM Parameter |
|----------|--------|--------------|
| HAProxy | 80 | `/iot/dev/haproxy/ip` |
| API Server 1 | 5000 | `/iot/dev/api-1/ip` |
| API Server 2 | 5000 | `/iot/dev/api-2/ip` |
| RabbitMQ | 5672, 15672 | `/iot/dev/rabbitmq/ip` |
| Worker | - | `/iot/dev/worker/ip` |
| PostgreSQL | 5432 | `/iot/dev/postgres/ip` |
| Producer | - | `/iot/dev/producer/ip` |

---

## Modos de Uso

### Modo Local (Docker Compose)
Para desarrollo y pruebas. Todo corre en contenedores Docker.

### Modo AWS (Terraform)
Para la actividad en AWS. 7 EC2s independientes con Terraform, Ubuntu 24.04 y Docker.

---

## Desarrollo Local

### Requisitos
- Docker Desktop
- Python 3.x (para el simulador)

### Levantando la Arquitectura

```bash
# Clonar repositorio
git clone https://github.com/tu-usuario/aws-iot-backend-architecture.git
cd aws-iot-backend-architecture

# Levantar servicios
docker compose up -d --build

# Verificar que están corriendo
docker compose ps
```

### Verificar Servicios

```bash
# Health check de API
curl http://localhost:5000/health

# Enviar datos de prueba
curl -X POST http://localhost:5000/api/sensor-data \
  -H "Content-Type: application/json" \
  -d '{"sensor_id": "TestSensor", "valor": 25.5}'
```

### Ver RabbitMQ

Abrir en navegador: http://localhost:15672
- Usuario: `guest`
- Contraseña: `guest`

### Ver Base de Datos

```bash
docker compose exec postgres psql -U admin -d iot_project
```

Consultar datos:
```sql
SELECT * FROM sensor_data LIMIT 10;
\q
```

### Ejecutar Simulador

```bash
# Crear venv e instalar
python3 -m venv venv
source venv/bin/activate
pip install requests

# Ejecutar simulador
python simulator/sensor_mock.py

# Salir del venv
deactivate
```

---

## Despliegue en AWS

### Estrategia de despliegue

- **Sistema operativo:** Ubuntu Server 24.04 LTS
- **Infraestructura:** Terraform
- **Artefactos de aplicación:** imágenes publicadas en Docker Hub
- **Conexiones internas:** Terraform inyecta IPs privadas en los contenedores
- **SSM Parameter Store:** Terraform publica IPs para verificacion/debug

### Imágenes requeridas

Antes de `terraform apply`, publica estas imágenes:

- `api/` -> imagen de la API Flask
- `worker/` -> imagen del Worker
- `simulator/` -> imagen del Producer

Ejemplo:

```bash
docker build -t <dockerhub-user>/aws-iot-api:latest ./api
docker build -t <dockerhub-user>/aws-iot-worker:latest ./worker
docker build -t <dockerhub-user>/aws-iot-producer:latest ./simulator

docker push <dockerhub-user>/aws-iot-api:latest
docker push <dockerhub-user>/aws-iot-worker:latest
docker push <dockerhub-user>/aws-iot-producer:latest
```

El proyecto ya trae por defecto estas imagenes en `terraform/variables.tf`:

```text
docker.io/jdavidruanob/aws-iot-api:latest
docker.io/jdavidruanob/aws-iot-worker:latest
docker.io/jdavidruanob/aws-iot-producer:latest
```

### Estructura de archivos Terraform

```
terraform/
├── providers.tf
├── variables.tf
├── main.tf
├── security_groups.tf
└── outputs.tf
```

### Pasos para desplegar

```bash
cd terraform

# Inicializar Terraform
terraform init

# Ver plan de cambios
terraform plan

# Aplicar cambios
terraform apply

# Ver IPs de los servicios
terraform output
```

### Endpoints después del despliegue

- **HAProxy URL:** `http://<HAProxy-Public-IP>/api/sensor-data`
- **RabbitMQ UI:** `http://<RabbitMQ-Public-IP>:15672`

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

Cada servicio tiene su propio script (`install_*.sh`):

| Script | Descripción |
|--------|-------------|
| `install_haproxy.sh` | HAProxy como contenedor Docker |
| `install_api.sh` | `docker pull` + `docker run` de la API |
| `install_rabbitmq.sh` | RabbitMQ en contenedor Docker |
| `install_worker.sh` | `docker pull` + `docker run` del Worker |
| `install_postgres.sh` | PostgreSQL en contenedor Docker |
| `install_producer.sh` | `docker pull` + `docker run` del Producer |

### Comportamiento de los scripts

1. Instala dependencias (Docker/nativo)
2. Configura el servicio
3. Descarga la imagen si aplica
4. Inicia el servicio

Los scripts ya no generan código inline dentro de las EC2.

## Pruebas

La guia completa de validacion y demo esta en [`pruebas.md`](./pruebas.md).

Smoke test automatico post-deploy:

```bash
SSH_KEY=~/code/iot/aws-iot-backend-architecture/iot_key.pem ./scripts/run_aws_smoke_tests.sh
```

Tambien se puede ejecutar pasando las IPs manualmente si Terraform corre dentro de otro contenedor.

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

### Credenciales

| Servicio | Usuario | Contraseña |
|----------|---------|------------|
| RabbitMQ | guest | guest |
| PostgreSQL | admin | adminpassword |

---

## Comandos Útiles

```bash
# Ver servicios
docker compose ps

# Ver logs
docker compose logs -f
docker compose logs iot_api --tail 50

# Reiniciar servicios
docker compose restart

# Detener todo
docker compose down

# Ruff linting
ruff check .
```

---

## Archivos del Proyecto

```
aws-iot-backend-architecture/
├── api/                      # API Flask
├── worker/                   # Worker consumidor
├── simulator/                # sensor_mock.py
├── terraform/                # Infructura AWS
├── install_*.sh              # Scripts para EC2s
├── get_parameter.py           # Helper SSM
├── docker-compose.yml        # Pruebas locales
├── SPEC.md                   # Especificación técnica
├── AGENTS.md                 # Convenciones para IAs
└── README.md                 # Este archivo
```
