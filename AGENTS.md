# AGENTS.md — AWS IoT Backend Architecture

## Actividad académica - Curso de IoT

Este proyecto implementa un sistema de backend asíncrono para ingestión de datos IoT, desplegado en AWS con 7 EC2s.

---

## Estructura del Proyecto

```
aws-iot-backend-architecture/
├── api/                     # API Flask (recibe datos de sensores)
├── worker/                 # Worker (consume RabbitMQ, guarda en PostgreSQL)
├── simulator/              # Producer (simula sensores IoT)
├── terraform/              # Infraestructura AWS (7 EC2s)
├── install_*.sh            # Scripts de instalación para EC2s
├── scripts/
│   └── run_aws_smoke_tests.sh  # Smoke test automático
├── get_parameter.py         # Helper SSM para debug
├── pruebas.md              # Guía de pruebas
└── README.md               # Documentación
```

---

## Arquitectura

**Flujo de datos:** Producer → HAProxy → API → RabbitMQ → Worker → PostgreSQL

**Servicios:**
- HAProxy (Load Balancer) - Puerto 80
- API Servers (x2) - Puerto 5000
- RabbitMQ (Message Broker) - Puertos 5672, 15672
- Worker - Puerto none (consume de RabbitMQ)
- PostgreSQL - Puerto 5432

**SSM Parameter Store:** `/iot/dev/{service}/ip` - Terraform publica IPs para debug.

---

## Configuración en AWS

### Variables de entorno inyectadas por Terraform

```python
# API
RABBITMQ_HOST = <rabbitmq-private-ip>

# Worker
RABBITMQ_HOST = <rabbitmq-private-ip>
POSTGRES_HOST = <postgres-private-ip>

# Producer
API_URL = http://<haproxy-public-ip>/api/sensor-data
```

**Regla:** No hardcodear IPs. Terraform maneja la conexión entre servicios.

---

## Comandos de Despliegue

### En el Learner Lab (con credenciales AWS temporales)

```bash
# Configurar credenciales
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_SESSION_TOKEN="..."
export AWS_DEFAULT_REGION="us-east-1"

# Verificar
aws sts get-caller-identity

# Desplegar
cd /app/terraform
terraform init
terraform plan
terraform apply   # escribir "yes"
terraform output  # obtener IPs
```

### Destruir todo

```bash
cd /app/terraform
terraform destroy
```

---

## Verificación Post-Deploy

```bash
# Health check (esperar 5-7 min después de apply)
curl http://<haproxy-ip>/health

# Enviar dato de prueba
curl -X POST http://<haproxy-ip>/api/sensor-data \
  -H "Content-Type: application/json" \
  -d '{"sensor_id":"TestSensor","valor":25.5}'

# RabbitMQ UI
# http://<rabbitmq-ip>:15672 (guest/guest)

# Smoke test automático
SSH_KEY=./iot_key.pem ./scripts/run_aws_smoke_tests.sh
```

---

## Archivos Clave

| Archivo | Propósito |
|---------|-----------|
| `api/main.py` | Flask API con `/api/sensor-data` (202) + `/health` |
| `worker/worker.py` | Consume `iot_tasks_queue`, inserta en PostgreSQL |
| `install_haproxy.sh` | HAProxy con IPs de APIs via `templatefile` |
| `terraform/main.tf` | 7 EC2s + SSM Parameters |

---

## Estilo de Código

- Python: 4 spaces, max 100 chars por línea
- Linting: `ruff check .`
- No `print()` en producción (usar logging)
- No imports sin usar

---

## Puertos en AWS

| Servicio | Puerto |
|----------|--------|
| HAProxy | 80 |
| API | 5000 |
| RabbitMQ AMQP | 5672 |
| RabbitMQ UI | 15672 |
| PostgreSQL | 5432 |

---

## Credenciales

| Servicio | Usuario | Contraseña |
|----------|---------|------------|
| RabbitMQ | guest | guest |
| PostgreSQL | admin | adminpassword |