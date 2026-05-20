import boto3
import os

class SSMParameterReader:
    def __init__(self):
        self.ssm_client = boto3.client('ssm')

    def get_parameter(self, name):
        try:
            response = self.ssm_client.get_parameter(
                Name=name,
                WithDecryption=True
            )
            return response['Parameter']['Value']
        except self.ssm_client.exceptions.ParameterNotFound:
            raise ValueError(f"Parameter {name} not found in SSM Parameter Store")
        except Exception as e:
            raise RuntimeError(f"Error reading SSM parameter {name}: {str(e)}")

def get_service_ip(service_name):
    """
    Obtiene la IP de un servicio desde SSM Parameter Store.
    El nombre del parámetro sigue el formato: /iot/dev/{service_name}/ip

    Args:
        service_name: Nombre del servicio (ej: 'rabbitmq', 'postgres', 'api-1')

    Returns:
        str: La IP del servicio

    Ejemplo:
        rabbitmq_ip = get_service_ip('rabbitmq')
    """
    parameter_name = f"/iot/dev/{service_name}/ip"
    reader = SSMParameterReader()
    return reader.get_parameter(parameter_name)

def get_all_service_ips():
    """
    Obtiene todas las IPs de servicios desde SSM.
    Útil para debugging o verificación.

    Returns:
        dict: Diccionario con todos los servicios y sus IPs
    """
    services = ['haproxy', 'api-1', 'api-2', 'rabbitmq', 'worker', 'postgres', 'producer']
    ips = {}

    for service in services:
        try:
            ips[service] = get_service_ip(service)
        except Exception as e:
            ips[service] = f"ERROR: {str(e)}"

    return ips

if __name__ == "__main__":
    print("=== SSM Parameter Reader ===")
    print("\nLeyendo IPs de SSM Parameter Store...\n")

    services = ['rabbitmq', 'postgres', 'worker', 'api-1', 'api-2', 'haproxy', 'producer']

    for service in services:
        try:
            ip = get_service_ip(service)
            print(f"[OK] {service}: {ip}")
        except Exception as e:
            print(f"[FAIL] {service}: {str(e)}")