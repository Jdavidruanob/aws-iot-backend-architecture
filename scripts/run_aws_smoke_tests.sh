#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TERRAFORM_DIR="${TERRAFORM_DIR:-$ROOT_DIR/terraform}"
SSH_KEY="${SSH_KEY:-}"
SSH_USER="${SSH_USER:-ubuntu}"
POSTGRES_PRIVATE_HOST="${POSTGRES_PRIVATE_HOST:-}"
TEST_COUNT="${TEST_COUNT:-5}"

if [[ -z "$SSH_KEY" ]]; then
  echo "ERROR: define SSH_KEY con la ruta al .pem"
  echo "Ejemplo: SSH_KEY=~/code/iot/aws-iot-backend-architecture/iot_key.pem $0"
  exit 1
fi

SSH_KEY="${SSH_KEY/#\~/$HOME}"

if [[ ! -f "$SSH_KEY" ]]; then
  echo "ERROR: no existe SSH_KEY: $SSH_KEY"
  exit 1
fi

need_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: falta el comando requerido: $1"
    exit 1
  fi
}

need_command curl
need_command python3
need_command ssh

tf_output() {
  local name="$1"
  terraform -chdir="$TERRAFORM_DIR" output -raw "$name"
}

get_value() {
  local env_name="$1"
  local output_name="$2"
  local env_value="${!env_name:-}"

  if command -v terraform >/dev/null 2>&1 && [[ -d "$TERRAFORM_DIR" ]]; then
    tf_output "$output_name"
    return
  fi

  if [[ -n "$env_value" ]]; then
    echo "$env_value"
    return
  fi

  echo "ERROR: no se pudo leer $output_name. Instala Terraform o define $env_name."
  exit 1
}

ssh_run() {
  local host="$1"
  shift
  ssh \
    -i "$SSH_KEY" \
    -o BatchMode=yes \
    -o StrictHostKeyChecking=accept-new \
    -o ConnectTimeout=10 \
    "$SSH_USER@$host" \
    "$@"
}

pass() {
  echo "[OK] $1"
}

section() {
  echo
  echo "== $1 =="
}

section "Leyendo datos del despliegue"

HAPROXY_PUBLIC_IP="$(get_value HAPROXY_PUBLIC_IP haproxy_public_ip)"
HAPROXY_URL="$(get_value HAPROXY_URL haproxy_url)"
RABBITMQ_PUBLIC_IP="$(get_value RABBITMQ_PUBLIC_IP rabbitmq_public_ip)"
WORKER_PUBLIC_IP="$(get_value WORKER_PUBLIC_IP worker_public_ip)"
PRODUCER_PUBLIC_IP="$(get_value PRODUCER_PUBLIC_IP producer_public_ip)"
POSTGRES_PUBLIC_IP="$(get_value POSTGRES_PUBLIC_IP postgres_public_ip)"

echo "HAProxy:   $HAPROXY_PUBLIC_IP"
echo "API URL:   $HAPROXY_URL"
echo "RabbitMQ:  $RABBITMQ_PUBLIC_IP"
echo "Worker:    $WORKER_PUBLIC_IP"
echo "Producer:  $PRODUCER_PUBLIC_IP"
echo "Postgres:  $POSTGRES_PUBLIC_IP"

section "Probando HAProxy health"

HEALTH_BODY="$(curl -fsS --max-time 20 "http://$HAPROXY_PUBLIC_IP/health")"
python3 - "$HEALTH_BODY" <<'PY'
import json
import sys

body = json.loads(sys.argv[1])
assert body.get("status") == "healthy", body
PY
pass "HAProxy responde /health"

section "Enviando datos por HAProxy"

for i in $(seq 1 "$TEST_COUNT"); do
  RESPONSE="$(curl -fsS --max-time 20 -X POST "$HAPROXY_URL" \
    -H "Content-Type: application/json" \
    -d "{\"sensor_id\":\"SmokeTest-$i\",\"valor\":$i}")"

  python3 - "$RESPONSE" <<'PY'
import json
import sys

body = json.loads(sys.argv[1])
assert "TaskId" in body, body
assert body.get("message") == "Dato recibido", body
print(body["TaskId"])
PY
done
pass "API acepta $TEST_COUNT mensajes y responde TaskId"

section "Probando RabbitMQ UI"

curl -fsSI --max-time 20 "http://$RABBITMQ_PUBLIC_IP:15672" >/dev/null
pass "RabbitMQ UI responde en :15672"

section "Validando Worker"

ssh_run "$WORKER_PUBLIC_IP" "sudo docker ps --format '{{.Names}} {{.Status}}' | grep '^iot-worker '" >/dev/null
pass "Contenedor iot-worker esta corriendo"

ssh_run "$WORKER_PUBLIC_IP" "sudo docker logs iot-worker --tail 200 | grep 'Guardado en BD con exito'" >/dev/null
pass "Worker registra inserciones exitosas en PostgreSQL"

section "Validando Producer"

ssh_run "$PRODUCER_PUBLIC_IP" "sudo docker ps --format '{{.Names}} {{.Status}}' | grep '^iot-producer '" >/dev/null
pass "Contenedor iot-producer esta corriendo"

ssh_run "$PRODUCER_PUBLIC_IP" "sudo docker logs iot-producer --tail 200 | grep 'TaskId:'" >/dev/null
pass "Producer registra envios exitosos"

section "Validando HAProxy config"

ssh_run "$HAPROXY_PUBLIC_IP" "sudo docker ps --format '{{.Names}} {{.Status}}' | grep '^iot-haproxy '" >/dev/null
pass "Contenedor iot-haproxy esta corriendo"

ssh_run "$HAPROXY_PUBLIC_IP" "sudo docker exec iot-haproxy cat /usr/local/etc/haproxy/haproxy.cfg | grep 'balance roundrobin'" >/dev/null
ssh_run "$HAPROXY_PUBLIC_IP" "sudo docker exec iot-haproxy cat /usr/local/etc/haproxy/haproxy.cfg | grep 'server api1'" >/dev/null
ssh_run "$HAPROXY_PUBLIC_IP" "sudo docker exec iot-haproxy cat /usr/local/etc/haproxy/haproxy.cfg | grep 'server api2'" >/dev/null
pass "HAProxy esta configurado con roundrobin y dos APIs"

section "Validando PostgreSQL"

if [[ -z "$POSTGRES_PRIVATE_HOST" ]]; then
  POSTGRES_PRIVATE_HOST="$(ssh_run "$WORKER_PUBLIC_IP" "sudo docker inspect iot-worker --format '{{range .Config.Env}}{{println .}}{{end}}' | sed -n 's/^POSTGRES_HOST=//p'")"
fi

echo "Postgres private host: $POSTGRES_PRIVATE_HOST"

DB_COUNT="$(ssh_run "$WORKER_PUBLIC_IP" "sudo docker run --rm -e PGPASSWORD=adminpassword postgres:15 psql -h '$POSTGRES_PRIVATE_HOST' -U admin -d iot_project -tAc 'SELECT COUNT(*) FROM sensor_data;'")"
DB_COUNT="$(echo "$DB_COUNT" | tr -d '[:space:]')"

if [[ "$DB_COUNT" =~ ^[0-9]+$ ]] && (( DB_COUNT > 0 )); then
  pass "PostgreSQL tiene $DB_COUNT registros en sensor_data"
else
  echo "ERROR: conteo invalido de PostgreSQL: $DB_COUNT"
  exit 1
fi

echo
echo "Smoke tests completados correctamente."
