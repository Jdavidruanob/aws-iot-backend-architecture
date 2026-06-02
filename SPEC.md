# Especificación Técnica - AWS IoT Backend Architecture

**Actividad académica del curso de IoT (Internet of Things)**

---

## Estado del Sistema

Sistema funcional desplegado en AWS con 7 EC2s independientes.

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

---

## Servicios y Componentes

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

## Credenciales

| Servicio | Usuario | Contraseña |
|----------|---------|------------|
| RabbitMQ | guest | guest |
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

## Flujo de Datos

```
1. Producer (sensor_mock.py) ──POST──▶ HAProxy :80
2. HAProxy ──balanceo roundrobin──▶ API-1 o API-2 :5000
3. API ──encola──▶ RabbitMQ (cola iot_tasks_queue)
4. API ◀──202 Accepted + TaskId
5. Worker ──consume──▶ RabbitMQ
6. Worker ──INSERT──▶ PostgreSQL (sensor_data)
7. Worker ──ack──▶ RabbitMQ
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
├── scripts/
│   └── run_aws_smoke_tests.sh  # Smoke test automático
├── install_*.sh             # Scripts para EC2s
├── get_parameter.py         # Helper SSM
├── pruebas.md               # Guía de pruebas
├── README.md                # Documentación
└── SPEC.md                  # Este archivo
```

---

## SSM Parameter Store

Terraform publica las IPs como referencia para verificación/debug:

```
/iot/dev/haproxy/ip
/iot/dev/api-1/ip
/iot/dev/api-2/ip
/iot/dev/rabbitmq/ip
/iot/dev/worker/ip
/iot/dev/postgres/ip
/iot/dev/producer/ip
```