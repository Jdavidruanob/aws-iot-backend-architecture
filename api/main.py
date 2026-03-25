from flask import Flask, request, jsonify
import pika
import json
import uuid

app = Flask(__name__)

def get_rabbitmq_connection():
    # Nos conectamos al contenedor de RabbitMQ usando las credenciales por defecto
    credentials = pika.PlainCredentials('guest', 'guest')
    # Usamos 'localhost' para pruebas locales (fuera de docker) o el nombre del servicio en docker
    # Por ahora dejaremos 'rabbitmq' que será el nombre del contenedor en el docker-compose
    parameters = pika.ConnectionParameters('rabbitmq', credentials=credentials)
    return pika.BlockingConnection(parameters)

@app.route('/api/sensor-data', methods=['POST'])
def receive_data():
    try:
        # 1. Extraemos los datos JSON que envía el sensor
        sensor_data = request.get_json()
        
        # 2. Generamos un ID único para esta tarea (TaskId) como pide el diagrama
        task_id = str(uuid.uuid4())
        
        # Le inyectamos el task_id a los datos originales
        payload = {
            "task_id": task_id,
            "data": sensor_data,
            "status": "pending"
        }

        # 3. Nos conectamos a RabbitMQ y enviamos el mensaje
        connection = get_rabbitmq_connection()
        channel = connection.channel()
        
        # Declaramos la cola (por si no existe) y enviamos el mensaje
        channel.queue_declare(queue='iot_tasks_queue', durable=True)
        channel.basic_publish(
            exchange='',
            routing_key='iot_tasks_queue',
            body=json.dumps(payload),
            properties=pika.BasicProperties(
                delivery_mode=2,  # Hace que el mensaje sea persistente aunque RabbitMQ se reinicie
            )
        )
        connection.close()

        # 4. Respondemos al usuario rápidamente (Código 202: Aceptado para procesamiento)
        return jsonify({"message": "Dato recibido", "TaskId": task_id}), 202

    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    # Ejecutamos la API en el puerto 5000
    app.run(host='0.0.0.0', port=5000, debug=True)