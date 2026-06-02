#!/usr/bin/env bash
# ============================================
# Script de Pruebas - Smoke Tests AWS IoT
# ============================================
#
# Uso:
#   SSH_KEY=/ruta/iot_key.pem ./run_aws_smoke_tests.sh
#
# ============================================

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TERRAFORM_DIR="${TERRAFORM_DIR:-$ROOT_DIR/terraform}"
SSH_KEY="${SSH_KEY:-}"
SSH_USER="${SSH_USER:-ubuntu}"
TEST_COUNT="${TEST_COUNT:-5}"

# Validar SSH_KEY
if [[ -z "$SSH_KEY" ]]; then
    echo "ERROR: Define SSH_KEY con la ruta al archivo .pem"
    exit 1
fi

SSH_KEY="${SSH_KEY/#\~/$HOME}"

if [[ ! -f "$SSH_KEY" ]]; then
    echo "ERROR: No existe: $SSH_KEY"
    exit 1
fi

# Comandos necesarios
command -v curl >/dev/null || { echo "ERROR: curl no encontrado"; exit 1; }
command -v python3 >/dev/null || { echo "ERROR: python3 no encontrado"; exit 1; }
command -v ssh >/dev/null || { echo "ERROR: ssh no encontrado"; exit 1; }

# Funcion para ejecutar comandos SSH
do_ssh() {
    ssh -i "$SSH_KEY" \
       -o StrictHostKeyChecking=no \
       -o ConnectTimeout=10 \
       -o BatchMode=yes \
       "$SSH_USER@$1" "$2"
}

# Obtener valor de Terraform o variable de entorno
get_val() {
    local env_name="$1"
    local tf_name="$2"
    local val="${!env_name:-}"

    if command -v terraform >/dev/null 2>&1 && [[ -d "$TERRAFORM_DIR" ]]; then
        terraform -chdir="$TERRAFORM_DIR" output -raw "$tf_name" 2>/dev/null && return
    fi

    if [[ -n "$val" ]]; then
        echo "$val"
        return
    fi

    echo "ERROR: No se encontro $tf_name"
    exit 1
}

echo "=========================================="
echo "SMOKE TESTS - AWS IoT Architecture"
echo "=========================================="
echo

# Obtener IPs
echo "== Leyendo IPs del despliegue =="
HAPROXY_IP="$(get_val HAPROXY_PUBLIC_IP haproxy_public_ip)"
HAPROXY_URL="$(get_val HAPROXY_URL haproxy_url)"
RABBITMQ_IP="$(get_val RABBITMQ_PUBLIC_IP rabbitmq_public_ip)"
WORKER_IP="$(get_val WORKER_PUBLIC_IP worker_public_ip)"
PRODUCER_IP="$(get_val PRODUCER_PUBLIC_IP producer_public_ip)"
POSTGRES_IP="$(get_val POSTGRES_PUBLIC_IP postgres_public_ip)"

echo "HAProxy:   $HAPROXY_IP"
echo "RabbitMQ:  $RABBITMQ_IP"
echo "Worker:    $WORKER_IP"
echo "Producer:  $PRODUCER_IP"
echo "Postgres:  $POSTGRES_IP"
echo

# ============================================
# Test 1: HAProxy /health
# ============================================
echo "== Test 1: HAProxy /health =="

HEALTH_RESP="$(curl -s "http://$HAPROXY_IP/health")"

python3 - "$HEALTH_RESP" <<'PY'
import json, sys
data = json.loads(sys.argv[1])
assert data.get("status") == "healthy", f"Status incorrecto: {data}"
print("Status:", data.get("status"))
PY

echo "[OK] HAProxy responde correctamente"
echo

# ============================================
# Test 2: Enviar datos de prueba
# ============================================
echo "== Test 2: Enviar $TEST_COUNT mensajes =="

for i in $(seq 1 $TEST_COUNT); do
    RESP="$(curl -s -X POST "$HAPROXY_URL" \
        -H "Content-Type: application/json" \
        -d "{\"sensor_id\":\"Test-$i\",\"valor\":$i}")"

    python3 - "$RESP" <<'PY'
import json, sys
data = json.loads(sys.argv[1])
assert "TaskId" in data, f"No hay TaskId: {data}"
print("  TaskId:", data["TaskId"][:8], "...")
PY
done

echo "[OK] API acepta mensajes"
echo

# ============================================
# Test 3: RabbitMQ UI
# ============================================
echo "== Test 3: RabbitMQ UI =="

RABBITMQ_RESP="$(curl -s -o /dev/null -w "%{http_code}" "http://$RABBITMQ_IP:15672")"

if [[ "$RABBITMQ_RESP" == "200" ]]; then
    echo "[OK] RabbitMQ UI accessible en puerto 15672"
else
    echo "ERROR: RabbitMQ respondio codigo $RABBITMQ_RESP"
    exit 1
fi
echo

# ============================================
# Test 4: Worker
# ============================================
echo "== Test 4: Worker =="

WORKER_RUNNING="$(do_ssh "$WORKER_IP" "sudo docker ps --format '{{.Names}}' | grep iot-worker")"

if [[ -n "$WORKER_RUNNING" ]]; then
    echo "[OK] iot-worker esta corriendo"
else
    echo "ERROR: iot-worker no esta corriendo"
    exit 1
fi

echo ""
echo "Logs recientes del Worker:"
echo "----------------------------"
do_ssh "$WORKER_IP" "sudo docker logs iot-worker --tail 10" 2>&1 | grep -E "Mensaje|Guardado" || echo "(sin mensajes recientes)"
echo

# ============================================
# Test 5: Producer
# ============================================
echo "== Test 5: Producer =="

PRODUCER_RUNNING="$(do_ssh "$PRODUCER_IP" "sudo docker ps --format '{{.Names}}' | grep iot-producer")"

if [[ -n "$PRODUCER_RUNNING" ]]; then
    echo "[OK] iot-producer esta corriendo"
else
    echo "ERROR: iot-producer no esta corriendo"
    exit 1
fi

echo ""
echo "Logs recientes del Producer:"
echo "----------------------------"
do_ssh "$PRODUCER_IP" "sudo docker logs iot-producer --tail 5" 2>&1 | grep "\+\+" || echo "(sin mensajes recientes)"
echo

# ============================================
# Test 6: HAProxy config
# ============================================
echo "== Test 6: HAProxy config =="

HAPROXY_RUNNING="$(do_ssh "$HAPROXY_IP" "sudo docker ps --format '{{.Names}}' | grep iot-haproxy")"

if [[ -n "$HAPROXY_RUNNING" ]]; then
    echo "[OK] iot-haproxy esta corriendo"
else
    echo "ERROR: iot-haproxy no esta corriendo"
    exit 1
fi

HAPROXY_CFG="$(do_ssh "$HAPROXY_IP" "sudo docker exec iot-haproxy cat /usr/local/etc/haproxy/haproxy.cfg")"

echo "$HAPROXY_CFG" | grep -q "balance roundrobin" && echo "[OK] roundrobin configurado"
echo "$HAPROXY_CFG" | grep -q "server api1" && echo "[OK] api1 configurada"
echo "$HAPROXY_CFG" | grep -q "server api2" && echo "[OK] api2 configurada"
echo

# ============================================
# Test 7: PostgreSQL
# ============================================
echo "== Test 7: PostgreSQL =="

# Obtener IP privada de PostgreSQL desde el Worker
POSTGRES_PRIVATE="$(do_ssh "$WORKER_IP" "sudo docker inspect iot-worker --format '{{range .Config.Env}}{{println .}}{{end}}' | grep POSTGRES_HOST | cut -d= -f2")"

if [[ -z "$POSTGRES_PRIVATE" ]]; then
    echo "ERROR: No se pudo obtener la IP de PostgreSQL desde Worker"
    exit 1
fi

echo "PostgreSQL privado: $POSTGRES_PRIVATE"

# Contar registros
DB_COUNT="$(do_ssh "$WORKER_IP" "sudo docker run --rm -e PGPASSWORD=adminpassword postgres:15 psql -h $POSTGRES_PRIVATE -U admin -d iot_project -tAc 'SELECT COUNT(*) FROM sensor_data;'")"
DB_COUNT="$(echo "$DB_COUNT" | tr -d '[:space:]')"
echo "Registros en sensor_data: $DB_COUNT"

if [[ "$DB_COUNT" =~ ^[0-9]+$ ]] && (( DB_COUNT > 0 )); then
    echo "[OK] PostgreSQL tiene datos"
else
    echo "WARNING: PostgreSQL no tiene registros"
fi

echo ""
echo "Ultimos 5 registros:"
echo "----------------------------"
do_ssh "$WORKER_IP" "sudo docker run --rm -e PGPASSWORD=adminpassword postgres:15 psql -h $POSTGRES_PRIVATE -U admin -d iot_project -c 'SELECT task_id, sensor_id, valor, status, fecha FROM sensor_data ORDER BY fecha DESC LIMIT 5;'"
echo

# ============================================
# Resumen
# ============================================
echo "=========================================="
echo "TODAS LAS PRUEBAS COMPLETADAS"
echo "=========================================="