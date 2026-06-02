# Pruebas de Despliegue AWS

Guía para demostrar que la arquitectura IoT funciona end-to-end en AWS.

**Nota:** Este proyecto está diseñado para funcionar exclusivamente en AWS con Terraform. No soporta modo local.

---

## Smoke Test Automático

El script `scripts/run_aws_smoke_tests.sh` valida todo el sistema automáticamente:

```bash
SSH_KEY=./iot_key.pem ./scripts/run_aws_smoke_tests.sh
```

Si ejecutas el script desde un contenedor sin Terraform local, pasa las IPs manualmente:

```bash
SSH_KEY=./iot_key.pem \
HAPROXY_PUBLIC_IP=54.237.160.6 \
HAPROXY_URL=http://54.237.160.6/api/sensor-data \
RABBITMQ_PUBLIC_IP=13.222.122.42 \
WORKER_PUBLIC_IP=98.92.190.96 \
PRODUCER_PUBLIC_IP=44.201.55.237 \
POSTGRES_PUBLIC_IP=44.198.58.211 \
./scripts/run_aws_smoke_tests.sh
```

El script valida:

1. HAProxy responde `/health`
2. API acepta mensajes POST y devuelve TaskId
3. RabbitMQ UI accesible en puerto 15672
4. Worker corriendo e insertando en PostgreSQL
5. Producer enviando datos
6. HAProxy configurado con roundrobin y 2 APIs
7. PostgreSQL con registros en `sensor_data`

---

## Ver Outputs de Terraform

```bash
cd /app/terraform
terraform output
```

---

## Pruebas Manuales

### Probar HAProxy

```bash
curl http://<haproxy-ip>/health
```

Respuesta esperada:

```json
{"status":"healthy"}
```

### Enviar dato manual

```bash
curl -X POST http://<haproxy-ip>/api/sensor-data \
  -H "Content-Type: application/json" \
  -d '{"sensor_id":"DemoSensor","valor":28.7}'
```

Respuesta esperada:

```json
{
  "TaskId": "...",
  "message": "Dato recibido"
}
```

### Enviar varios datos

```bash
for i in {1..10}; do
  curl -s -X POST http://<haproxy-ip>/api/sensor-data \
    -H "Content-Type: application/json" \
    -d "{\"sensor_id\":\"DemoSensor-$i\",\"valor\":$i}"
  echo
done
```

---

## Ver Servicios

### RabbitMQ UI

Abrir en navegador: `http://<rabbitmq-ip>:15672`

Credenciales:
- Usuario: `guest`
- Contraseña: `guest`

Ruta: `Queues and Streams -> iot_tasks_queue`

Si la cola queda en `0` mensajes, es buena señal: el Worker está consumiendo rápido.

### Worker

```bash
ssh -i iot_key.pem ubuntu@<worker-ip>

# Ver contenedores
sudo docker ps

# Ver logs
sudo docker logs iot-worker --tail 100
```

Salida esperada:

```
INFO:__main__:Mensaje recibido: ...
INFO:__main__:Guardado en BD con exito. Task: ...
```

### Producer

```bash
ssh -i iot_key.pem ubuntu@<producer-ip>

# Ver logs
sudo docker logs iot-producer --tail 100
```

Salida esperada:

```
[+] Sensor_Temp_Cocina -> 25.3 | TaskId: ...
```

### HAProxy

```bash
ssh -i iot_key.pem ubuntu@<haproxy-ip>

# Ver configuración
sudo docker exec iot-haproxy cat /usr/local/etc/haproxy/haproxy.cfg
```

Debe mostrar:

```
balance roundrobin
server api1 <private-ip>:5000 check
server api2 <private-ip>:5000 check
```

---

## Consultar PostgreSQL

Desde el Worker:

```bash
ssh -i iot_key.pem ubuntu@<worker-ip>

# Obtener IP privada de PostgreSQL
echo $POSTGRES_HOST

# Consultar datos
sudo docker run --rm -e PGPASSWORD=adminpassword postgres:15 psql \
  -h $POSTGRES_HOST -U admin -d iot_project -c "SELECT * FROM sensor_data LIMIT 10;"
```

---

## Guía para Demo

### Orden recomendado

1. `terraform output` - mostrar IPs
2. `curl /health` - HAProxy funcionando
3. RabbitMQ UI abierta
4. Logs del Producer
5. Logs del Worker
6. Consulta en PostgreSQL
7. Config de HAProxy mostrando api1/api2

### Script para explicar

```
El sistema está desplegado con Terraform en 7 EC2.
La entrada pública es HAProxy (puerto 80).
HAProxy balancea entre dos APIs Flask (roundrobin).
Las APIs reciben datos y responden 202 con un TaskId.
Luego publican el mensaje en RabbitMQ.
El Worker consume la cola y guarda los datos en PostgreSQL.
El Producer es otra EC2 que simula sensores enviando datos continuamente.
```