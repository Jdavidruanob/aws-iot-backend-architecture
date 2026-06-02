# Context: AWS IoT Backend Architecture

## Información del Proyecto

**Actividad académica del curso de IoT (Internet of Things)**

Este proyecto implementa un sistema de backend para la ingestión masiva y asíncrona de datos provenientes de sensores IoT. El sistema está diseñado bajo un enfoque de **microservicios desacoplados** para garantizar que la recepción de datos nunca se bloquee por procesos lentos de escritura en base de datos.

---

## Arquitectura

```
┌─── Client Side ─────────────────────────────────────────┐
│                                                          │
│  [ Producer (sensor_mock.py) ]                          │
│  Simula sensores IoT enviando datos continuamente        │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─── AWS Infrastructure ──────────────────────────────────┐
│                                                          │
│  [ HAProxy - Load Balancer EC2 :80 ]                    │
│           │                                              │
│           ▼                                              │
│  ┌─── API Servers ──────────────────────────────────┐  │
│  │  [ API REST - Flask :5000 ]  ──►  [ RabbitMQ ]    │  │
│  │          │  ▲                                   │  │
│  │  (202)   │  │  TaskId                    Consume│  │
│  │          ▼  │                                   ▼  │
│  │  [ PostgreSQL DB ]  ◄──── INSERT ──────────────[Worker]
│  │                                                     │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

---

## Estado Actual: Desplegado en 7 EC2s

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

- HAProxy recibe tráfico y balancea entre las 2 API Servers (roundrobin)
- Las API Servers solo aceptan tráfico desde HAProxy (security group)
- Worker consume de RabbitMQ y escribe en PostgreSQL
- Terraform inyecta IPs privadas en los contenedores para comunicación runtime
- Terraform publica IPs en SSM Parameter Store para referencia y verificación

---

## Flujo de Datos Completo

```
1. Producer EC2 ejecuta sensor_mock.py en Docker
   └── Recibe la URL de HAProxy desde Terraform (user_data)

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

## Detalles Técnicos

- **Sistema operativo:** Ubuntu Server 24.04 LTS
- **Infraestructura como Código:** Terraform
- **Protocolo de Mensajería:** AMQP vía RabbitMQ (Puerto `5672`)
- **Persistencia:** PostgreSQL (Puerto `5432`)
- **API:** Flask en puerto `5000`
- **Balanceador:** HAProxy en puerto `80`
- **Respuesta Asíncrona:** HTTP `202 Accepted` + `TaskId (UUID)`

---

## Credenciales

| Servicio | Usuario | Contraseña |
|----------|---------|------------|
| RabbitMQ | guest | guest |
| PostgreSQL | admin | adminpassword |

---

## Archivos del Proyecto

```
aws-iot-backend-architecture/
├── api/                     # API Flask
├── worker/                  # Worker consumidor
├── simulator/               # sensor_mock.py
├── terraform/               # Infraestructura AWS (7 EC2s)
├── scripts/                 # Smoke tests
├── install_*.sh             # Scripts para EC2s
├── get_parameter.py         # Helper SSM
├── pruebas.md               # Guía de pruebas
├── README.md                # Documentación
└── SPEC.md                  # Especificación técnica
```