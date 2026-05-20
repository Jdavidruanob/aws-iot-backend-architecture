# Proyecto IoT Backend - Arquitectura Distribuida AWS

## Estado Actual: Sistema Funcional

El proyecto implementa un sistema de backend asíncrono para ingestión de datos IoT. Actualmente funciona en **2 modos**:

### Modo Local (Docker Compose)
- 4 contenedores en 1 máquina
- Para desarrollo y pruebas

### Modo Distribuido (AWS Terraform)
- 7 EC2s independientes
- Para despliegue de la actividad
- Ubuntu Server 24.04 LTS + Docker

---

## Arquitectura del Sistema

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

---

## Servicios y Componentes

| Servicio | Puerto | Descripción | SSM Parameter |
|----------|--------|-------------|---------------|
| HAProxy | 80 | Load Balancer, recibe tráfico del Producer | `/iot/dev/haproxy/ip` |
| API Server 1 | 5000 | Flask API, encola a RabbitMQ | `/iot/dev/api-1/ip` |
| API Server 2 | 5000 | Flask API (backup AZ) | `/iot/dev/api-2/ip` |
| RabbitMQ | 5672, 15672 | Message Broker, cola `iot_tasks_queue` | `/iot/dev/rabbitmq/ip` |
| Worker | - | Consume cola, escribe en PostgreSQL | `/iot/dev/worker/ip` |
| PostgreSQL | 5432 | Base de datos, tabla `sensor_data` | `/iot/dev/postgres/ip` |
| Producer | - | Ejecuta sensor_mock.py | `/iot/dev/producer/ip` |

---

## Credenciales

| Servicio | Usuario | Contraseña |
|----------|---------|------------|
| RabbitMQ | guest | guest |
| PostgreSQL | admin | adminpassword |

---

## Endpoints de la API

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

---

## SSM Parameter Store

Terraform publica las IPs como referencia para verificacion/debug:
```
/iot/dev/haproxy/ip
/iot/dev/api-1/ip
/iot/dev/api-2/ip
/iot/dev/rabbitmq/ip
/iot/dev/worker/ip
/iot/dev/postgres/ip
/iot/dev/producer/ip
```

---

## Dependencias Python

**API (api/requirements.txt):**
- Flask==3.0.2
- pika==1.3.2

**Worker (worker/requirements.txt):**
- pika==1.3.2
- psycopg2-binary==2.9.11

---

## Variables de Entorno

Para ejecución local (Docker Compose):
```yaml
USE_LOCAL_ENV: "true"
RABBITMQ_HOST: "rabbitmq"
POSTGRES_HOST: "postgres"
```

Para ejecución en AWS (EC2s):
- Terraform inyecta variables de entorno en los contenedores
- API recibe `RABBITMQ_HOST`
- Worker recibe `RABBITMQ_HOST` y `POSTGRES_HOST`

---

## Flujo de Datos

```
1. Producer (sensor_mock.py) ──POST──▶ HAProxy :80
2. HAProxy ──balanceo──▶ API-1 o API-2 :5000
3. API ──encola──▶ RabbitMQ (cola iot_tasks_queue)
4. Worker ──consume──▶ PostgreSQL (INSERT)
5. Producer ◀──202 Accepted + TaskId
```

---

## Archivos del Proyecto

```
aws-iot-backend-architecture/
├── api/
│   ├── main.py              # API Flask
│   ├── Dockerfile
│   └── requirements.txt
├── worker/
│   ├── worker.py            # Consumidor
│   ├── Dockerfile
│   └── requirements.txt
├── simulator/
│   ├── sensor_mock.py       # Simulador de sensores
│   ├── Dockerfile
│   └── requirements.txt
├── terraform/
│   ├── providers.tf
│   ├── variables.tf
│   ├── main.tf              # 7 EC2s
│   ├── security_groups.tf
│   └── outputs.tf
├── install_*.sh             # Scripts para EC2s
│   ├── install_haproxy.sh
│   ├── install_api.sh
│   ├── install_rabbitmq.sh
│   ├── install_worker.sh
│   ├── install_postgres.sh
│   └── install_producer.sh
├── get_parameter.py         # Helper SSM para debug/verificacion
├── pruebas.md               # Guia de demo y validacion
├── docker-compose.yml       # Pruebas locales
├── SPEC.md                  # Este archivo
├── AGENTS.md                # Convenciones de código
└── context_project.md       # Contexto general del proyecto
```
