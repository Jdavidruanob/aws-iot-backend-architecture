import pika
import psycopg2
import json
import time
import os
import logging

logging.basicConfig(level=logging.INFO)
LOGGER = logging.getLogger(__name__)


def get_rabbitmq_ip():
    rabbitmq_host = os.environ.get('RABBITMQ_HOST')
    if rabbitmq_host:
        return rabbitmq_host
    raise RuntimeError("RABBITMQ_HOST is required")


def get_postgres_ip():
    postgres_host = os.environ.get('POSTGRES_HOST')
    if postgres_host:
        return postgres_host
    raise RuntimeError("POSTGRES_HOST is required")


RABBITMQ_IP = None
POSTGRES_IP = None

# Credenciales de la base de datos
DB_PORT = "5432"
DB_NAME = "iot_project"
DB_USER = "admin"
DB_PASS = "adminpassword"


def get_db_connection():
    # PostgreSQL puede tardar en iniciar, reintentamos cada 2 segundos
    global POSTGRES_IP

    while True:
        try:
            if POSTGRES_IP is None:
                POSTGRES_IP = get_postgres_ip()
            conn = psycopg2.connect(
                host=POSTGRES_IP,
                port=DB_PORT,
                dbname=DB_NAME,
                user=DB_USER,
                password=DB_PASS
            )
            return conn
        except Exception:
            POSTGRES_IP = None
            LOGGER.info("Esperando a que PostgreSQL inicie...")
            time.sleep(2)


def init_db():
    # Crea la tabla si no existe (idempotente)
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute('''
        CREATE TABLE IF NOT EXISTS sensor_data (
            id SERIAL PRIMARY KEY,
            task_id VARCHAR(255) UNIQUE NOT NULL,
            sensor_id VARCHAR(50) NOT NULL,
            valor FLOAT NOT NULL,
            status VARCHAR(20) NOT NULL,
            fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    conn.commit()
    cur.close()
    conn.close()
    LOGGER.info("Base de datos inicializada correctamente.")


def callback(ch, method, properties, body):
    # Procesa cada mensaje de la cola
    # Si falla el INSERT, el mensaje queda en la cola para reintento
    mensaje = json.loads(body.decode()) # decodificar y formatear el mensaje
    LOGGER.info("Mensaje recibido: %s", mensaje['task_id'])

    task_id = mensaje['task_id']
    sensor_id = mensaje['data']['sensor_id']
    valor = mensaje['data']['valor']
    status = "completed" # marcar como completado 

    try: # insertar en postgress
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute(
            "INSERT INTO sensor_data (task_id, sensor_id, valor, status) VALUES (%s, %s, %s, %s)",
            (task_id, sensor_id, valor, status)
        )
        conn.commit()
        cur.close()
        conn.close()

        LOGGER.info("Guardado en BD con exito. Task: %s", task_id)
        # confirmar mensaje para que rabbit lo saque de la cola.
        ch.basic_ack(delivery_tag=method.delivery_tag) 

    except Exception as e:
        LOGGER.exception("Error al guardar en BD: %s", e)


def main():
    # Obtiene IPs desde SSM, inicializa DB y comienza a consumir mensajes
    global RABBITMQ_IP
    init_db()

    while True:
        try:
            RABBITMQ_IP = get_rabbitmq_ip()
            LOGGER.info("Conectando a RabbitMQ en: %s", RABBITMQ_IP)
            credentials = pika.PlainCredentials('guest', 'guest')
            parameters = pika.ConnectionParameters(RABBITMQ_IP, credentials=credentials)
            connection = pika.BlockingConnection(parameters)
            break
        except Exception:
            LOGGER.info("Esperando a que RabbitMQ inicie...")
            time.sleep(2)

    channel = connection.channel()
    channel.queue_declare(queue='iot_tasks_queue', durable=True)
    channel.basic_consume(queue='iot_tasks_queue', on_message_callback=callback, auto_ack=False)

    LOGGER.info("Worker iniciado. Esperando mensajes.")
    channel.start_consuming()


if __name__ == '__main__':
    main()
