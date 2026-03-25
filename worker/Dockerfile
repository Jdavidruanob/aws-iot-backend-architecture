FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# A diferencia de la API, el worker no expone puertos porque nadie se conecta a él, 
# él es quien se conecta a RabbitMQ y Postgres.
CMD ["python", "worker.py"]