variable "aws_region" {
  description = "Region de AWS"
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "VPC ID donde se crearan las EC2"
  type        = string
  default     = "vpc-0d0beafd98e1ba6f1"
}

variable "subnet_id" {
  description = "Subnet ID para la zona de disponibilidad 1"
  type        = string
  default     = "subnet-0dd84a9293cb6cf9a"
}

variable "subnet_id_2" {
  description = "Subnet ID para la zona de disponibilidad 2"
  type        = string
  default     = "subnet-0d8edeb3135c1bd44"
}

variable "ami_id" {
  description = "AMI ID para Ubuntu Server 24.04 LTS"
  type        = string
  default     = "ami-05cf1e9f73fbad2e2"
}

variable "key_name" {
  description = "Nombre de la key pair para SSH"
  type        = string
  default     = "iot_key"
}

variable "instance_type" {
  description = "Tipo de instancia EC2"
  type        = string
  default     = "t2.micro"
}

variable "api_image" {
  description = "Imagen Docker Hub para la API Flask"
  type        = string
  default     = "docker.io/jdavidruanob/aws-iot-api:latest"
}

variable "worker_image" {
  description = "Imagen Docker Hub para el Worker"
  type        = string
  default     = "docker.io/jdavidruanob/aws-iot-worker:latest"
}

variable "producer_image" {
  description = "Imagen Docker Hub para el simulador Producer"
  type        = string
  default     = "docker.io/jdavidruanob/aws-iot-producer:latest"
}
