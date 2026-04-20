terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# --- VPC & NETWORKING ---
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# --- SECURITY GROUPS ---

# SG para el Balanceador (Solo puerto 80)
resource "aws_security_group" "alb_sg" {
  name        = "iot_alb_sg"
  description = "Acceso HTTP para el balanceador"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
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

# SG para la Servidor (Puertos internos y administracion)
resource "aws_security_group" "ec2_sg" {
  name        = "iot_ec2_sg"
  description = "Reglas para servicios IoT en EC2"
  vpc_id      = data.aws_vpc.default.id

  # SSH para administracion y DBeaver
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Tráfico desde el ALB a la API Flask
  ingress {
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  # PostgreSQL para DBeaver
  ingress {
    from_port   = 5433
    to_port     = 5433
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # RabbitMQ Management UI para monitoreo
  ingress {
    from_port   = 15672
    to_port     = 15672
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

# --- INFRAESTRUCTURA DE BALANCEO ---

resource "aws_lb" "iot_alb" {
  name               = "iot-backend-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = data.aws_subnets.default.ids

  tags = {
    Name = "IoT-ALB"
  }
}

resource "aws_lb_target_group" "iot_tg" {
  name     = "iot-target-group"
  port     = 5000
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/api/sensor-data"
    port                = "5000"
    protocol            = "HTTP"
    matcher             = "200,405" # Clave para que Flask no de Unhealthy
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.iot_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.iot_tg.arn
  }
}

# --- COMPUTO (EC2) ---

resource "aws_instance" "iot_server" {
  ami           = "ami-0c7217cdde317cfec" 
  instance_type = "t3.micro"
  key_name      = "vockey" 

  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  
  # Script de instalacion automatica
  user_data = file("${path.module}/user_data.sh")

  tags = {
    Name = "IoT-Worker-Server"
  }
}

# Unir servidor al grupo de destino del balanceador
resource "aws_lb_target_group_attachment" "iot_attachment" {
  target_group_arn = aws_lb_target_group.iot_tg.arn
  target_id        = aws_instance.iot_server.id
  port             = 5000
}

# --- RESULTADOS FINALES ---

output "ip_publica_servidor" {
  description = "Usa esta IP para SSH, RabbitMQ y DBeaver"
  value       = aws_instance.iot_server.public_ip
}

output "url_para_simulador" {
  description = "Copia esta URL en tu script de Python"
  value       = "http://${aws_lb.iot_alb.dns_name}/api/sensor-data"
}