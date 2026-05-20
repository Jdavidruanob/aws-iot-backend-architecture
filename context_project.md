# Project Context: IoT Backend Architecture

## 1. Idea Central del Proyecto

El objetivo es construir un sistema de backend para la ingestión masiva y asíncrona de datos provenientes de sensores IoT. El sistema está diseñado bajo un enfoque de **microservicios desacoplados** para garantizar que la recepción de datos nunca se bloquee por procesos lentos de escritura en base de datos o procesamiento pesado.

---

## 2. Diagrama de Arquitectura (Estructural)

```
┌─── Client Side ──────────────────┐
│                                  │
│  [ Productor Eventos Sintéticos ] │
│  [ Actor / Usuario              ] │
└──────────────┬───────────────────┘
               │
               ▼
┌─── AWS Infrastructure ───────────────────────────────────────────┐
│                                                                   │
│  [ HAProxy - Load Balancer EC2 :80 ]                             │
│           │                                                       │
│           ▼                                                       │
│  ┌─── API Servers ────────────────────────────────────────────┐   │
│  │  [ API REST - Flask :5000 ]  ──(3) Encola──►  [ RabbitMQ ]│  │
│  │          │  ▲                                      │      │   │
│  │  (2)     │  │ 202 TaskId                    Consume│      │   │
│  │ Consulta │  │                                      ▼      │   │
│  │          ▼  │                               [ Worker ]    │   │
│  │  [ PostgreSQL DB ]  ◄──── Update TaskId / Create Order ───┘   │
│  │                                                           │   │
│  └───────────────────────────────────────────────────────────┘   │
└───────────────────────────────────────────────────────────────────┘

Flujo de Ingesta:  Productor ──POST(1)──► HAProxy ──► API ──► RabbitMQ ──► Worker ──► DB
Flujo de Consulta: Actor ──GET Task/TaskId──► API ──(2)──► DB
```

---

## 3. Estado Actual: Fase 2 (Distribuida en 7 EC2s)

El sistema ha sido migrado de un monolito Docker Compose a una arquitectura distribuida con **7 EC2s independientes**.

### Infraestructura AWS

| EC2 | Servicio | Puerto | SSM Parameter |
|-----|----------|--------|--------------|
| 1 | HAProxy (Load Balancer) | 80 | `/iot/dev/haproxy/ip` |
| 2 | API Server 1 | 5000 | `/iot/dev/api-1/ip` |
| 3 | API Server 2 | 5000 | `/iot/dev/api-2/ip` |
| 4 | RabbitMQ | 5672, 15672 | `/iot/dev/rabbitmq/ip` |
| 5 | Worker | - | `/iot/dev/worker/ip` |
| 6 | PostgreSQL | 5432 | `/iot/dev/postgres/ip` |
| 7 | Producer (sensor_mock.py) | - | `/iot/dev/producer/ip` |

### Arquitectura de Red

- HAProxy recibe tráfico y balancea entre las 2 API Servers
- Las API Servers solo aceptan tráfico desde el HAProxy (security group)
- Worker consume de RabbitMQ y escribe en PostgreSQL
- Terraform inyecta IPs privadas en los contenedores para comunicacion runtime
- Terraform publica IPs en SSM Parameter Store para referencia y verificacion
- Productor recibe la URL publica de HAProxy desde Terraform

---

## 4. Versión Local (Docker Compose)

Para desarrollo y pruebas, el sistema funciona con Docker Compose en una sola máquina.

```bash
docker compose up -d --build
```

Servicios: API, Worker, RabbitMQ, PostgreSQL

---

## 5. Cambios Realizados

### Configuracion runtime

- `api/main.py` - Usa `RABBITMQ_HOST`
- `worker/worker.py` - Usa `RABBITMQ_HOST` y `POSTGRES_HOST`
- `get_parameter.py` - Helper opcional para leer parametros SSM en verificaciones

### Scripts de Instalación

- `install_haproxy.sh` - HAProxy con IPs de APIs inyectadas via Terraform
- `install_api.sh` - API Flask desde Docker Hub
- `install_rabbitmq.sh` - RabbitMQ en Docker
- `install_worker.sh` - Worker desde Docker Hub
- `install_postgres.sh` - PostgreSQL en Docker
- `install_producer.sh` - Producer desde Docker Hub

### Terraform

- 7 EC2s con sus Security Groups
- Ubuntu Server 24.04 LTS
- SSM Parameter Store para referencia/debug
- HAProxy usa `templatefile` para recibir IPs de APIs

---

## 6. Detalles Técnicos

- **Protocolo de Mensajería:** AMQP vía RabbitMQ (Puerto `5672`)
- **Persistencia:** PostgreSQL (Puerto `5432`)
- **API:** Flask en puerto `5000`
- **Balanceador:** HAProxy en puerto `80`
- **Respuesta Asíncrona:** HTTP `202 Accepted` + `TaskId (UUID)`

---

## 7. Archivos del Proyecto

```
aws-iot-backend-architecture/
├── api/                     # API Flask
├── worker/                  # Worker consumidor
├── simulator/               # sensor_mock.py
├── terraform/               # IaC para AWS
├── install_*.sh             # Scripts para EC2s
├── get_parameter.py         # Helper SSM
├── docker-compose.yml       # Pruebas locales
├── SPEC.md                  # Especificación técnica
├── AGENTS.md                # Convenciones para IAs
├── README.md                # Documentación
└── context_project.md       # Este archivo
```

---

## 8. Flujo de Datos Completo

```
1. Productor EC2 ejecuta sensor_mock.py en Docker
   └── Recibe la URL de HAProxy desde Terraform

2. sensor_mock.py ──POST /api/sensor-data──► HAProxy EC2 :80

3. HAProxy ──balanceo roundrobin──► API Server 1 o 2 :5000

4. API Server recibe:
   - Extrae {sensor_id, valor}
   - Genera TaskId (UUID)
   - Encola a RabbitMQ (cola iot_tasks_queue)
   - Responde 202 + TaskId

5. Worker EC2:
   - Consume de RabbitMQ
   - INSERT INTO PostgreSQL (sensor_data)
   - Confirma a RabbitMQ (ack)

6. Los datos quedan disponibles en la tabla `sensor_data`
```

---

## 9. Convenciones y Reglas

Ver `AGENTS.md` para:
- Estilo de código (Ruff)
- Reglas de linting
- Variables de entorno
- Workflow de desarrollo

---

Última actualización: 2026-05-04
