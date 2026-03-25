# Usamos una imagen de Python ligera
FROM python:3.11-slim

# Creamos y nos movemos a la carpeta /app dentro del contenedor
WORKDIR /app

# Copiamos primero el archivo de requerimientos y los instalamos
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copiamos el resto del código de la API
COPY . .

# Exponemos el puerto que usa Flask
EXPOSE 5000

# Comando para ejecutar la aplicación
CMD ["python", "main.py"]