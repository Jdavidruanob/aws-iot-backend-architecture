import requests
import time
import random

# La dirección de tu API local
API_URL = "http://localhost:5000/api/sensor-data"

# Nombres de sensores simulados
SENSORES = ["Sensor_Temp_Cocina", "Sensor_Temp_Sala", "Humedad_Invernadero", "Presion_Valvula_1"]

print("🚀 Iniciando enjambre de sensores IoT...")
print("Presiona CTRL+C en la terminal para detener la simulación.\n")

try:
    while True:
        # 1. Generamos datos aleatorios para darle realismo
        sensor_elegido = random.choice(SENSORES)
        # Genera un valor aleatorio entre 10.0 y 40.0 con dos decimales
        valor_generado = round(random.uniform(10.0, 40.0), 2) 

        payload = {
            "sensor_id": sensor_elegido,
            "valor": valor_generado
        }

        try:
            # 2. Hacemos la petición POST a tu API (Igual que el comando de PowerShell)
            respuesta = requests.post(API_URL, json=payload)

            # 3. Verificamos si la API lo aceptó (Código 202 que programaste)
            if respuesta.status_code == 202:
                datos_respuesta = respuesta.json()
                print(f"[+] Enviado: {sensor_elegido} -> {valor_generado} | TaskId: {datos_respuesta['TaskId'].split('-')[0]}...")
            else:
                print(f"[-] La API rechazó el dato. Código: {respuesta.status_code}")
                
        except requests.exceptions.ConnectionError:
            print("[-] Error de conexión: ¿Está encendido el contenedor de la API?")

        # 4. Pausa aleatoria entre 0.5 y 2 segundos antes de que otro sensor envíe un dato
        tiempo_espera = random.uniform(0.5, 2.0)
        time.sleep(tiempo_espera)

except KeyboardInterrupt:
    print("\n🛑 Simulador detenido por el usuario.")