import pika
import psycopg2
import json
import time
import os

# Credenciales de la Base de Datos (las mismas del docker-compose)
DB_HOST = "postgres" # Nombre del servicio en docker-compose
DB_PORT = "5432"     # Puerto interno de Postgres
DB_NAME = "iot_project"
DB_USER = "admin"
DB_PASS = "adminpassword"

def get_db_connection():
    # Intentamos conectar a la BD con reintentos (por si la BD tarda en encender)
    while True:
        try:
            conn = psycopg2.connect(
                host=DB_HOST,
                port=DB_PORT,
                dbname=DB_NAME,
                user=DB_USER,
                password=DB_PASS
            )
            return conn
        except psycopg2.OperationalError:
            print("Esperando a que PostgreSQL inicie...")
            time.sleep(2)

def init_db():
    # Crea la tabla si no existe
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
    print("Base de datos inicializada correctamente.")

def callback(ch, method, properties, body):
    # Esta función se ejecuta CADA VEZ que llega un mensaje nuevo a RabbitMQ
    mensaje = json.loads(body.decode())
    print(f" [x] Mensaje recibido: {mensaje['task_id']}")
    
    task_id = mensaje['task_id']
    sensor_id = mensaje['data']['sensor_id']
    valor = mensaje['data']['valor']
    status = "completed" # Cambiamos el estado a completado
    
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        # Insertamos los datos en PostgreSQL
        cur.execute(
            "INSERT INTO sensor_data (task_id, sensor_id, valor, status) VALUES (%s, %s, %s, %s)",
            (task_id, sensor_id, valor, status)
        )
        conn.commit()
        cur.close()
        conn.close()
        
        print(f" [v] Guardado en BD con éxito. Task: {task_id}")
        
        # Le confirmamos a RabbitMQ que ya puede borrar el mensaje de la cola
        ch.basic_ack(delivery_tag=method.delivery_tag)
        
    except Exception as e:
        print(f" [!] Error al guardar en BD: {e}")
        # Si falla, no enviamos el ack, así RabbitMQ intentará enviarlo de nuevo después

def main():
    init_db()
    
    # Conectamos a RabbitMQ
    credentials = pika.PlainCredentials('guest', 'guest')
    parameters = pika.ConnectionParameters('rabbitmq', credentials=credentials)
    
    # Reintentos para conectar a RabbitMQ
    while True:
        try:
            connection = pika.BlockingConnection(parameters)
            break
        except pika.exceptions.AMQPConnectionError:
            print("Esperando a que RabbitMQ inicie...")
            time.sleep(2)
            
    channel = connection.channel()
    channel.queue_declare(queue='iot_tasks_queue', durable=True)
    
    # auto_ack=False asegura que si el worker falla a la mitad, no se pierda el dato
    channel.basic_consume(queue='iot_tasks_queue', on_message_callback=callback, auto_ack=False)
    
    print(' [*] Worker iniciado. Esperando mensajes. Para salir presione CTRL+C')
    channel.start_consuming()

if __name__ == '__main__':
    main()