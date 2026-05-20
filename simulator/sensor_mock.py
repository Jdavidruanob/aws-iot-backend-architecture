import requests
import time
import random
import os

# URL de la API configurada via variable de entorno
# En local (Docker Compose): http://localhost:5000
# En AWS (EC2): se inyecta via install_producer.sh desde SSM
API_URL = os.environ.get('API_URL', 'http://localhost:5000/api/sensor-data')

# Sensores simulados en el enjambre IoT
SENSORES = ["Sensor_Temp_Cocina", "Sensor_Temp_Sala", "Humedad_Invernadero", "Presion_Valvula_1"]

print("Iniciando enjambre de sensores IoT...")
print(f"Conectando a: {API_URL}")
print("Presiona CTRL+C para detener.\n")

try:
    while True:
        # Selección aleatoria de sensor y valor para simular datos realistas
        sensor_elegido = random.choice(SENSORES)
        valor_generado = round(random.uniform(10.0, 40.0), 2)

        payload = {
            "sensor_id": sensor_elegido,
            "valor": valor_generado
        }

        try:
            respuesta = requests.post(API_URL, json=payload, timeout=10)

            if respuesta.status_code == 202:
                datos_respuesta = respuesta.json()
                # Mostramos solo los primeros caracteres del TaskId para legibilidad
                print(f"[+] {sensor_elegido} -> {valor_generado} | TaskId: {datos_respuesta['TaskId'].split('-')[0]}...")
            else:
                print(f"[-] La API rechazo el dato. Codigo: {respuesta.status_code}")

        except requests.exceptions.ConnectionError:
            print("[-] Error de conexion. Verifica que la API este corriendo.")

        # Intervalo aleatorio para simular patrones de sensores reales
        # (algunos sensores envían más frecuentemente que otros)
        tiempo_espera = random.uniform(0.5, 2.0)
        time.sleep(tiempo_espera)

except KeyboardInterrupt:
    print("\nSimulador detenido.")
