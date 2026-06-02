# ============================================
# Security Groups - Configuran qué tráfico
# puede entrar/salir de cada EC2
# ============================================

# HAProxy - Puerto 80 entrada (HTTP desde internet)
# Puerto 22 para administración SSH
resource "aws_security_group" "haproxy_sg" {
  name   = "iot-haproxy-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH - Abrir a 0.0.0.0/0 SOLO en desarrollo/Learner Lab
  # En producción: usar SSM Session Manager (sin abrir puertos) o
  # restringir a tu IP específica: cidr_blocks = ["tu_ip_publica/32"]
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# API Servers - Puerto 5000 solo desde HAProxy
# SSH (22) para administración
resource "aws_security_group" "api_sg" {
  name   = "iot-api-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.haproxy_sg.id]
  }

  # SSH - Abrir a 0.0.0.0/0 SOLO en desarrollo/Learner Lab
  # En producción: usar SSM Session Manager (sin abrir puertos) o
  # restringir a tu IP específica: cidr_blocks = ["tu_ip_publica/32"]
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# RabbitMQ - Puerto 5672 (AMQP) desde API y Worker
# Puerto 15672 (Management UI) abierto para monitoreo
resource "aws_security_group" "rabbitmq_sg" {
  name   = "iot-rabbitmq-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port       = 5672
    to_port         = 5672
    protocol        = "tcp"
    security_groups = [aws_security_group.api_sg.id, aws_security_group.worker_sg.id]
  }

  # Puerto 15672 (Management UI) - En producción restringir a tu IP:
  # cidr_blocks = ["tu_ip_publica/32"]
  ingress {
    from_port   = 15672
    to_port     = 15672
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH - Abrir a 0.0.0.0/0 SOLO en desarrollo/Learner Lab
  # En producción: usar SSM Session Manager (sin abrir puertos) o
  # restringir a tu IP específica: cidr_blocks = ["tu_ip_publica/32"]
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Worker - Solo SSH para administración
# No expone puertos, solo se conecta a RabbitMQ y PostgreSQL
resource "aws_security_group" "worker_sg" {
  name   = "iot-worker-sg"
  vpc_id = var.vpc_id

  # SSH - Abrir a 0.0.0.0/0 SOLO en desarrollo/Learner Lab
  # En producción: usar SSM Session Manager (sin abrir puertos) o
  # restringir a tu IP específica: cidr_blocks = ["tu_ip_publica/32"]
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# PostgreSQL - Puerto 5432 solo desde Worker
# No tiene acceso desde internet
resource "aws_security_group" "postgres_sg" {
  name   = "iot-postgres-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.worker_sg.id]
  }

  # SSH - Abrir a 0.0.0.0/0 SOLO en desarrollo/Learner Lab
  # En producción: usar SSM Session Manager (sin abrir puertos) o
  # restringir a tu IP específica: cidr_blocks = ["tu_ip_publica/32"]
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Producer - Solo SSH, sale a internet para enviar datos a HAProxy
resource "aws_security_group" "producer_sg" {
  name   = "iot-producer-sg"
  vpc_id = var.vpc_id

  # SSH - Abrir a 0.0.0.0/0 SOLO en desarrollo/Learner Lab
  # En producción: usar SSM Session Manager (sin abrir puertos) o
  # restringir a tu IP específica: cidr_blocks = ["tu_ip_publica/32"]
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
