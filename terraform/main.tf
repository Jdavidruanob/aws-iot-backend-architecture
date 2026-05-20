# ============================================
# 7 EC2s para arquitectura IoT distribuida.
# Terraform inyecta las IPs privadas necesarias en el user_data.
# ============================================

# 1. RabbitMQ - Message Broker
# Recibe mensajes de las APIs y los encola para el Worker
resource "aws_instance" "rabbitmq" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.rabbitmq_sg.id]
  user_data               = file("${path.module}/../install_rabbitmq.sh")

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  tags = {
    Name = "RabbitMQ-Server"
    Role = "MessageBroker"
  }
}

# 2. API Server 1 - Primera replica en AZ 1
# Flask API que recibe datos de sensores y los encola a RabbitMQ
resource "aws_instance" "api_server_1" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.api_sg.id]
  user_data              = templatefile("${path.module}/../install_api.sh", {
    api_image     = var.api_image
    rabbitmq_host = aws_instance.rabbitmq.private_ip
  })

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  tags = {
    Name = "API-Server-1"
    Role = "BackendAPI"
  }
}

# 3. API Server 2 - Segunda replica en AZ 2
# Backup de la API para alta disponibilidad
resource "aws_instance" "api_server_2" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = var.subnet_id_2
  vpc_security_group_ids = [aws_security_group.api_sg.id]
  user_data              = templatefile("${path.module}/../install_api.sh", {
    api_image     = var.api_image
    rabbitmq_host = aws_instance.rabbitmq.private_ip
  })

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  tags = {
    Name = "API-Server-2"
    Role = "BackendAPI"
  }
}

# 4. HAProxy - Load Balancer
# Recibe trafico del Producer y balancea entre las 2 APIs
# Las IPs de las APIs se pasan via templatefile (interpolacion de Terraform)
resource "aws_instance" "haproxy" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.haproxy_sg.id]

  user_data = templatefile("${path.module}/../install_haproxy.sh", {
    api_server_1_ip = aws_instance.api_server_1.private_ip
    api_server_2_ip = aws_instance.api_server_2.private_ip
  })

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  tags = {
    Name = "HAProxy-LoadBalancer"
    Role = "LoadBalancer"
  }
}

# 5. Worker - Procesador asincrono
# Consume mensajes de RabbitMQ y los guarda en PostgreSQL
resource "aws_instance" "worker" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.worker_sg.id]
  user_data              = templatefile("${path.module}/../install_worker.sh", {
    postgres_host = aws_instance.postgres.private_ip
    rabbitmq_host = aws_instance.rabbitmq.private_ip
    worker_image  = var.worker_image
  })

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  tags = {
    Name    = "Worker-Server"
    Role    = "AsyncWorker"
  }
}

# 6. PostgreSQL - Base de datos
# Almacena los datos de sensores procesados
resource "aws_instance" "postgres" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.postgres_sg.id]
  user_data               = file("${path.module}/../install_postgres.sh")

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  tags = {
    Name    = "Postgres-Server"
    Role    = "Database"
  }
}

# 7. Producer - Simulador de sensores IoT
# Ejecuta sensor_mock.py que envia datos a HAProxy
resource "aws_instance" "producer" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.producer_sg.id]
  user_data              = templatefile("${path.module}/../install_producer.sh", {
    api_url         = "http://${aws_instance.haproxy.public_ip}/api/sensor-data"
    producer_image  = var.producer_image
  })

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  tags = {
    Name    = "Producer-Server"
    Role    = "IoTSimulator"
  }
}

# ============================================
# SSM Parameter Store
# Terraform publica las IPs como referencia para verificacion/debug.
# La comunicacion runtime usa IPs privadas inyectadas por user_data.
# ============================================

resource "aws_ssm_parameter" "rabbitmq_ip" {
  name  = "/iot/dev/rabbitmq/ip"
  type  = "String"
  value = aws_instance.rabbitmq.private_ip
}

resource "aws_ssm_parameter" "api_1_ip" {
  name  = "/iot/dev/api-1/ip"
  type  = "String"
  value = aws_instance.api_server_1.private_ip
}

resource "aws_ssm_parameter" "api_2_ip" {
  name  = "/iot/dev/api-2/ip"
  type  = "String"
  value = aws_instance.api_server_2.private_ip
}

resource "aws_ssm_parameter" "haproxy_ip" {
  name  = "/iot/dev/haproxy/ip"
  type  = "String"
  value = aws_instance.haproxy.public_ip
}

resource "aws_ssm_parameter" "worker_ip" {
  name  = "/iot/dev/worker/ip"
  type  = "String"
  value = aws_instance.worker.private_ip
}

resource "aws_ssm_parameter" "postgres_ip" {
  name        = "/iot/dev/postgres/ip"
  type        = "String"
  value       = aws_instance.postgres.private_ip
}

resource "aws_ssm_parameter" "producer_ip" {
  name        = "/iot/dev/producer/ip"
  type        = "String"
  value       = aws_instance.producer.private_ip
}
