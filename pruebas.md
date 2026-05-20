# Pruebas de Despliegue AWS

Guia para demostrar que la arquitectura IoT funciona end-to-end.

## 0. Pruebas automaticas

El repo incluye un smoke test post-deploy:

```bash
SSH_KEY=~/code/iot/aws-iot-backend-architecture/iot_key.pem ./scripts/run_aws_smoke_tests.sh
```

Si lo quieres correr desde tu maquina local sin Terraform instalado, pasa las IPs de `terraform output`:

```bash
SSH_KEY=~/code/iot/aws-iot-backend-architecture/iot_key.pem \
HAPROXY_PUBLIC_IP=54.237.160.6 \
HAPROXY_URL=http://54.237.160.6/api/sensor-data \
RABBITMQ_PUBLIC_IP=13.222.122.42 \
WORKER_PUBLIC_IP=98.92.190.96 \
PRODUCER_PUBLIC_IP=44.201.55.237 \
POSTGRES_PUBLIC_IP=44.198.58.211 \
./scripts/run_aws_smoke_tests.sh
```

Si ejecutas el script desde un lugar distinto a la raiz del repo, define tambien `TERRAFORM_DIR`:

```bash
SSH_KEY=~/code/iot/aws-iot-backend-architecture/iot_key.pem \
TERRAFORM_DIR=/home/jdavidruanob/code/iot/aws-iot-backend-architecture/terraform \
/home/jdavidruanob/code/iot/aws-iot-backend-architecture/scripts/run_aws_smoke_tests.sh
```

El script valida:

```text
1. terraform output
2. HAProxy /health
3. POST /api/sensor-data
4. RabbitMQ UI
5. Worker corriendo y guardando en BD
6. Producer enviando datos
7. HAProxy con roundrobin hacia dos APIs
8. PostgreSQL con registros en sensor_data
```

## 1. Ver outputs de Terraform

Desde el contenedor donde se ejecuta Terraform:

```bash
cd /app/terraform
terraform output
```

Outputs actuales de referencia:

```text
api_server_1_public_ip = "13.220.34.154"
api_server_2_public_ip = "44.204.193.205"
haproxy_public_ip = "54.237.160.6"
haproxy_url = "http://54.237.160.6/api/sensor-data"
postgres_public_ip = "44.198.58.211"
producer_public_ip = "44.201.55.237"
rabbitmq_public_ip = "13.222.122.42"
worker_public_ip = "98.92.190.96"
```

## 2. Probar HAProxy

```bash
curl http://54.237.160.6/health
```

Respuesta esperada:

```json
{"status":"healthy"}
```

## 3. Enviar dato manual

```bash
curl -X POST http://54.237.160.6/api/sensor-data \
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

Enviar varios datos para ver actividad:

```bash
for i in {1..10}; do
  curl -s -X POST http://54.237.160.6/api/sensor-data \
    -H "Content-Type: application/json" \
    -d "{\"sensor_id\":\"DemoSensor-$i\",\"valor\":$i}"
  echo
done
```

## 4. Ver RabbitMQ

Abrir en navegador:

```text
http://13.222.122.42:15672
```

Credenciales:

```text
Usuario: guest
Password: guest
```

Ruta en la UI:

```text
Queues and Streams -> iot_tasks_queue
```

Si la cola queda en `0` mensajes, es una buena senal: el Worker esta consumiendo rapido.

## 5. Ver Worker

Conectarse por SSH:

```bash
ssh -i iot_key.pem ubuntu@98.92.190.96
```

Ver contenedor:

```bash
sudo docker ps -a
```

Ver logs:

```bash
sudo docker logs iot-worker --tail 100
```

Salida esperada:

```text
Mensaje recibido: ...
Guardado en BD con exito. Task: ...
```

## 6. Consultar PostgreSQL desde Worker

Desde la EC2 Worker:

```bash
sudo docker run --rm -it postgres:15 psql \
  -h 172.31.6.16 \
  -U admin \
  -d iot_project
```

Password:

```text
adminpassword
```

Consulta:

```sql
SELECT * FROM sensor_data ORDER BY fecha DESC LIMIT 10;
```

Salir de `psql`:

```sql
\q
```

## 7. Ver Producer automatico

Conectarse por SSH:

```bash
ssh -i iot_key.pem ubuntu@44.201.55.237
```

Ver logs:

```bash
sudo docker logs iot-producer --tail 100
```

Salida esperada:

```text
[+] Sensor_Temp_Cocina -> 25.3 | TaskId: ...
```

## 8. Ver configuracion del Load Balancer

Conectarse a HAProxy:

```bash
ssh -i iot_key.pem ubuntu@54.237.160.6
```

Ver contenedor:

```bash
sudo docker ps -a
```

Ver configuracion:

```bash
sudo docker exec iot-haproxy cat /usr/local/etc/haproxy/haproxy.cfg
```

Debe verse:

```text
balance roundrobin
server api1 <private-ip-api-1>:5000 check
server api2 <private-ip-api-2>:5000 check
```

Ver logs:

```bash
sudo docker logs iot-haproxy --tail 100
```

## 9. Guion corto para explicar

```text
El sistema esta desplegado con Terraform en 7 EC2.
La entrada publica es HAProxy.
HAProxy balancea entre dos APIs Flask.
Las APIs reciben datos y responden 202 con un TaskId.
Luego publican el mensaje en RabbitMQ.
El Worker consume la cola y guarda los datos en PostgreSQL.
El Producer es otra EC2 que simula sensores enviando datos continuamente.
```

## 10. Orden recomendado de demo

```text
1. terraform output
2. curl /health
3. RabbitMQ UI abierta
4. curl POST manual o logs del Producer
5. logs del Worker
6. SELECT en PostgreSQL
7. config de HAProxy mostrando api1/api2
```
