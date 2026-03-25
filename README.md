# 🌐 AWS IoT Async Data Pipeline

Este proyecto implementa una arquitectura backend asíncrona y escalable diseñada para procesar ráfagas de datos provenientes de dispositivos IoT. 

El sistema utiliza un enrutador de mensajes (Message Broker) para desacoplar la recepción de datos de su almacenamiento, asegurando alta disponibilidad y evitando cuellos de botella en la base de datos durante picos de tráfico.

## 🏗️ Arquitectura del Sistema

El flujo de los datos sigue esta ruta:

1. **IoT Sensors (Simulador):** Dispositivos que generan lecturas (ej. temperatura, humedad) y las envían vía HTTP POST.
2. **API REST (Flask):** Puerta de entrada rápida. Recibe el *payload*, le asigna un `task_id` único y lo empuja a la cola de mensajes, respondiendo al cliente inmediatamente (HTTP 202).
3. **RabbitMQ (Message Broker):** Almacena los mensajes en memoria en la cola `iot_tasks_queue` de forma segura hasta que puedan ser procesados.
4. **Worker (Python):** Consumidor en segundo plano que extrae mensajes de RabbitMQ, los procesa y los inserta de forma persistente.
5. **PostgreSQL:** Base de datos relacional donde se almacena el estado final de las lecturas.

## 🛠️ Tecnologías Utilizadas

* **Lenguaje:** Python 3.11
* **Framework Web:** Flask
* **Message Broker:** RabbitMQ
* **Base de Datos:** PostgreSQL 15
* **Infraestructura Local:** Docker & Docker Compose

## 🚀 Guía de Instalación (Entorno Local)

### Requisitos Previos

* [Docker Desktop](https://www.docker.com/products/docker-desktop/) instalado y en ejecución.
* Python 3.x instalado en la máquina anfitriona (solo para ejecutar el simulador).

### Levantando la Arquitectura

1. Clona este repositorio:

```bash
git clone https://github.com/TU_USUARIO/aws-iot-backend-architecture.git
cd aws-iot-backend-architecture
```

2. Construye e inicia todos los microservicios usando Docker Compose:

```bash
docker compose up -d --build
```

3. Verifica que los 4 contenedores (`iot_api`, `iot_worker`, `iot_rabbitmq`, `iot_postgres`) estén en estado **Up** o **Started**.

## 🧪 Pruebas y Simulación de Tráfico

Para ver la arquitectura en acción, el proyecto incluye un simulador de enjambre de sensores IoT.

1. Instala la dependencia del simulador en tu entorno local:

```bash
pip install requests
```

2. Ejecuta el simulador:

```bash
python simulator/sensor_mock.py
```

## 📊 Monitoreo

Mientras el simulador envía datos, puedes observar el comportamiento del sistema en tiempo real:

**RabbitMQ Dashboard:**
Visita http://localhost:15672  
Usuario: `guest`  
Contraseña: `guest`  
En la pestaña **Queues** podrás ver el flujo de entrada y salida de mensajes.

**Base de Datos:**
Conéctate usando DBeaver u otro cliente SQL con las siguientes credenciales:

- Host: `localhost`
- Port: `5433` *(mapeado localmente para evitar conflictos)*
- Database: `iot_project`
- User: `admin`
- Password: `adminpassword`

## ☁️ Próximos Pasos (En desarrollo)

- [ ] Despliegue manual de infraestructura en AWS (EC2, ALB, RDS)
- [ ] Automatización de infraestructura como código (IaC) utilizando Terraform

---

## ⚡ Paso rápido para actualizar GitHub

```bash
git add README.md
git commit -m "docs: Agregada documentacion de arquitectura e instrucciones locales al README"
git push
```