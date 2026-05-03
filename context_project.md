# Project Context: IoT Backend Architecture

## 1. Idea Central del Proyecto

El objetivo es construir un sistema de backend para la ingesta masiva y
asíncrona de datos provenientes de sensores IoT. El sistema está
diseñado bajo un enfoque de **microservicios desacoplados** para
garantizar que la recepción de datos nunca se bloquee por procesos
lentos de escritura en base de datos o procesamiento pesado.

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
│  [ ALB - Application Load Balancer ]                              │
│           │                                                       │
│           ▼                                                       │
│  ┌─── Services ──────────────────────────────────────────────┐   │
│  │                                                           │   │
│  │  [ API REST - Flask :5000 ]  ──(3) Encola──►  [ RabbitMQ ]│  │
│  │          │  ▲                                      │      │   │
│  │  (2)     │  │ 202 TaskId                    Consume│      │   │
│  │ Consulta │  │                                      ▼      │   │
│  │          ▼  │                               [ Worker ]    │   │
│  │  [ PostgreSQL DB ]  ◄──── Update TaskId / Create Order ───┘   │
│  │                                                           │   │
│  └───────────────────────────────────────────────────────────┘   │
└───────────────────────────────────────────────────────────────────┘

Flujo de Ingesta:  Productor ──POST(1)──► ALB ──► API ──► RabbitMQ ──► Worker ──► DB
Flujo de Consulta: Actor ──GET Task/TaskId──► API ──(2)──► DB
```

---

## 3. Estado Actual: Fase 1 (Monolítica en EC2)

Actualmente, el sistema ha sido validado exitosamente corriendo en una
sola instancia EC2 (`t3.micro`).

-   **Orquestación:**\
    Se utiliza `docker-compose.yml` para levantar 4 contenedores:

    -   API
    -   Worker
    -   RabbitMQ
    -   PostgreSQL

-   **Red:**\
    Los contenedores se comunican internamente mediante la red de Docker
    usando nombres de servicio.

-   **Despliegue:**\
    Automatizado mediante Terraform y un script `user_data.sh` que
    instala Docker y clona el repositorio.

---

## 4. Próximo Paso: Fase 2 (Refactorización Distribuida)

El objetivo inmediato es evolucionar la arquitectura hacia un modelo de
alta disponibilidad y escalabilidad real.

### Requisitos:

-   **Infraestructura como Código (IaC):**\
    Adaptar el proyecto a Terraform (OpenTofu) para separar los
    servicios.

-   **Un servicio por máquina:**\
    Cada componente debe correr en su propia instancia EC2
    independiente:

    -   API
    -   RabbitMQ
    -   Worker
    -   PostgreSQL

-   **AWS Parameter Store:**

    -   Las máquinas ya no usarán nombres de red de Docker.
    -   El código debe obtener dinámicamente las IPs privadas desde AWS
        Systems Manager Parameter Store.

-   **Balanceador de Carga (ALB):**

    -   Implementar un Application Load Balancer.
    -   La API debe tener mínimo 2 instancias activas detrás del ALB.

---

## 5. Detalles Técnicos Relevantes

-   **Protocolo de Mensajería:** AMQP vía RabbitMQ (Puerto `5672`)
-   **Persistencia:** PostgreSQL (Puerto `5432`)
-   **API:** Flask en puerto `5000`
-   **Respuesta Asíncrona:** HTTP `202 Accepted` + `TaskId (UUID)`

---

## 6. Entregables Esperados

-   Repositorio en GitHub (EN/ES)
-   Pruebas unitarias
-   Análisis estático (Ruff)
-   Swagger API Docs
-   Infraestructura distribuida en AWS

---

## 📌 Uso del archivo

Este archivo sirve como **contexto base para IA**.

Permite que cualquier modelo entienda rápidamente: 1. Qué ya funciona 2.
Qué falta construir 3. Cómo fluye la arquitectura
