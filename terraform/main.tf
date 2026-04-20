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

data "aws_vpc" "default" { default = true }
data "aws_subnets" "default" {
  filter { name = "vpc-id", values = [data.aws_vpc.default.id] }
}

resource "aws_security_group" "alb_sg" {
  name = "iot_alb_sg"
  vpc_id = data.aws_vpc.default.id
  ingress { from_port = 80, to_port = 80, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] }
  egress { from_port = 0, to_port = 0, protocol = "-1", cidr_blocks = ["0.0.0.0/0"] }
}

resource "aws_security_group" "ec2_sg" {
  name = "iot_ec2_sg"
  vpc_id = data.aws_vpc.default.id
  ingress { from_port = 22, to_port = 22, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] }
  ingress { from_port = 5000, to_port = 5000, protocol = "tcp", security_groups = [aws_security_group.alb_sg.id] }
  ingress { from_port = 5433, to_port = 5433, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] }
  ingress { from_port = 15672, to_port = 15672, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] }
  egress { from_port = 0, to_port = 0, protocol = "-1", cidr_blocks = ["0.0.0.0/0"] }
}

resource "aws_lb" "iot_alb" {
  name = "iot-backend-alb"
  load_balancer_type = "application"
  security_groups = [aws_security_group.alb_sg.id]
  subnets = data.aws_subnets.default.ids
}

resource "aws_lb_target_group" "iot_tg" {
  name = "iot-target-group"
  port = 5000
  protocol = "HTTP"
  vpc_id = data.aws_vpc.default.id
  health_check { path = "/api/sensor-data", matcher = "200,405" }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.iot_alb.arn
  port = "80"
  protocol = "HTTP"
  default_action { type = "forward", target_group_arn = aws_lb_target_group.iot_tg.arn }
}

resource "aws_instance" "iot_server" {
  ami = "ami-0c7217cdde317cfec"
  instance_type = "t3.micro"
  key_name = "vockey"
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  user_data = file("${path.module}/user_data.sh")
}

resource "aws_lb_target_group_attachment" "iot_attachment" {
  target_group_arn = aws_lb_target_group.iot_tg.arn
  target_id = aws_instance.iot_server.id
  port = 5000
}

output "ip_publica_servidor" { value = aws_instance.iot_server.public_ip }
output "url_para_simulador" { value = "http://${aws_lb.iot_alb.dns_name}/api/sensor-data" }