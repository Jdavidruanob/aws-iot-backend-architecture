import json
import logging
import os
import uuid

import pika
from flask import Flask, jsonify, request

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)
LOGGER = logging.getLogger(__name__)

# Cache de IP de RabbitMQ para evitar consultas repetidas a SSM
# En producción (AWS), cada consulta a SSM tiene latencia y costo
RABBITMQ_IP = None


def get_rabbitmq_ip():
    """
    Obtiene el host de RabbitMQ desde variables de entorno.

    Estrategia:
    1. Si RABBITMQ_HOST existe, usa ese valor.
    2. Si USE_LOCAL_ENV=true, usa el hostname local de Docker Compose.
    """
    rabbitmq_host = os.environ.get('RABBITMQ_HOST')
    if rabbitmq_host:
        return rabbitmq_host
    if os.environ.get('USE_LOCAL_ENV', 'false').lower() == 'true':
        return 'rabbitmq'
    raise RuntimeError("RABBITMQ_HOST is required outside local mode")


def get_rabbitmq_connection():
    """
    Crea conexión persistente a RabbitMQ.

    Uso de cache: La IP se cachea en RABBITMQ_IP para evitar
    consultar SSM en cada request (reduce latencia y costos de API).
    """
    global RABBITMQ_IP
    credentials = pika.PlainCredentials('guest', 'guest')

    while True:
        try:
            if RABBITMQ_IP is None:
                RABBITMQ_IP = get_rabbitmq_ip()
            parameters = pika.ConnectionParameters(RABBITMQ_IP, credentials=credentials)
            return pika.BlockingConnection(parameters)
        except Exception as exc:
            LOGGER.warning("RabbitMQ is not ready yet: %s", exc)
            RABBITMQ_IP = None
            import time
            time.sleep(3)


def init_rabbitmq():
    """Inicializa la cola durable al arrancar la API."""
    connection = get_rabbitmq_connection()
    channel = connection.channel()
    channel.queue_declare(queue='iot_tasks_queue', durable=True)
    connection.close()

@app.route('/api/sensor-data', methods=['POST'])
def receive_data():
    """
    Endpoint principal para recibir datos de sensores IoT.

    Flujo:
    1. Extrae sensor_id y valor del body JSON
    2. Genera TaskId (UUID) para tracking asíncrono
    3. Encola mensaje en RabbitMQ (no bloquea)
    4. Retorna 202 Accepted inmediatamente

    El Worker se encargará de persistir a PostgreSQL.
    El cliente puede usar el TaskId para consultar estado.
    """
    try:
        sensor_data = request.get_json()
        task_id = str(uuid.uuid4())

        payload = {
            "task_id": task_id,
            "data": sensor_data,
            "status": "pending"
        }

        connection = get_rabbitmq_connection()
        channel = connection.channel()
        channel.queue_declare(queue='iot_tasks_queue', durable=True)
        channel.basic_publish(
            exchange='',
            routing_key='iot_tasks_queue',
            body=json.dumps(payload),
            # delivery_mode=2 = mensaje persistente (sobrevive a reinicios de RabbitMQ)
            properties=pika.BasicProperties(delivery_mode=2)
        )
        connection.close()

        return jsonify({"message": "Dato recibido", "TaskId": task_id}), 202

    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route('/health', methods=['GET'])
def health_check():
    """
    Health check para HAProxy.

    HAProxy usa este endpoint para saber si la API está viva.
    Se consulta regularmente para hacer balanceo activo.
    """
    return jsonify({"status": "healthy"}), 200


if __name__ == '__main__':
    init_rabbitmq()
    app.run(host='0.0.0.0', port=5000, debug=False)
