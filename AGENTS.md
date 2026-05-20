# AGENTS.md — AWS IoT Backend Architecture

## Repo Structure

```
aws-iot-backend-architecture/
├── api/main.py              # Flask API (local dev entrypoint)
├── worker/worker.py          # RabbitMQ consumer (local dev entrypoint)
├── simulator/sensor_mock.py # IoT sensor simulator
├── install_*.sh             # EC2 provisioning scripts (docker pull/run)
├── terraform/               # 7 EC2s + SSM Parameter Store
├── get_parameter.py         # SSM helper for debug/verification
├── pruebas.md               # AWS demo/validation commands
└── docker-compose.yml       # Local dev (4 containers)
```

## Architecture

**Data flow:** Producer → HAProxy → Flask API → RabbitMQ → Worker → PostgreSQL

**Services:** HAProxy (LB :80), API×2 (:5000), RabbitMQ (AMQP :5672 + UI :15672), Worker, PostgreSQL (:5432)

**SSM path pattern:** `/iot/dev/{service}/ip` — Terraform publishes IPs for verification/debug.

**AWS runtime config:** Terraform injects private IPs into containers through env vars.

## AWS Deployment Steps

### 1. Antes de terraform apply

**Importante:** Crear la key pair EN AWS Console ANTES de hacer apply:
1. AWS Console → EC2 → Key Pairs → Create key pair
2. Nombre: `iot_key`, formato: `.pem`
3. Descargar y guardar en lugar seguro
4. **No destruir las instancias si quieres mantener la key**

### 2. Credentials temporales del Learner Lab

Cada vez que se recreate el contenedor, setear credenciales:
```bash
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_SESSION_TOKEN="..."
export AWS_DEFAULT_REGION="us-east-1"
```

Verificar con:
```bash
aws sts get-caller-identity
```

### 3. Terraform commands

```bash
cd /app/terraform
terraform init
terraform plan
terraform apply   # escribir "yes"
terraform output  # obtener IPs
```

### 4. Verificación

```bash
# Health check (esperar 5-7 min después de apply)
curl http://<haproxy-ip>/health

# Enviar dato de prueba
curl -X POST http://<haproxy-ip>/api/sensor-data \
  -H "Content-Type: application/json" \
  -d '{"sensor_id":"TestSensor","valor":25.5}'

# Ver RabbitMQ UI
# http://<rabbitmq-ip>:15672  (guest/guest)

# Ver PostgreSQL via DBeaver o psql
# Host: <postgres-ip>, Port: 5432, DB: iot_project, User: admin, Pass: adminpassword
```

### 5. Destruir todo

```bash
cd /app/terraform
terraform destroy
```

## Service Discovery Pattern

```python
# Local: USE_LOCAL_ENV=true → env var fallback
if os.environ.get('USE_LOCAL_ENV', 'false').lower() == 'true':
    return os.environ.get('RABBITMQ_HOST', 'rabbitmq')

# AWS: Terraform injects env vars in user_data
RABBITMQ_HOST=<rabbitmq-private-ip>
POSTGRES_HOST=<postgres-private-ip>
```

**Rule:** Never hardcode hostnames/IPs in Python. Use env vars in runtime; Terraform owns AWS wiring.

## Key Files

| File | Purpose |
|------|---------|
| `api/main.py` | Flask API with `/api/sensor-data` (202) + `/health` |
| `worker/worker.py` | Consumes `iot_tasks_queue`, inserts to PostgreSQL |
| `install_haproxy.sh` | HAProxy config injected via Terraform `templatefile` |
| `terraform/main.tf` | 7 EC2s + SSM parameters; HAProxy uses `templatefile` for API IPs |

## Code Style

- Python: 4 spaces, max 100 chars
- Linting: `ruff check .`
- No `print()` in production (use logging)
- No unused imports

## Ports

| Service | Local | AWS |
|---------|-------|-----|
| HAProxy | :80 | :80 |
| API | :5000 | :5000 |
| RabbitMQ | :5672, :15672 | :5672, :15672 |
| PostgreSQL | :5433→:5432 | :5432 |
