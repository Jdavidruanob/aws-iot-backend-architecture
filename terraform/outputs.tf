output "rabbitmq_public_ip" {
  value       = aws_instance.rabbitmq.public_ip
  description = "IP publica del servidor RabbitMQ"
}

output "haproxy_public_ip" {
  value       = aws_instance.haproxy.public_ip
  description = "IP publica del HAProxy Load Balancer"
}

output "api_server_1_public_ip" {
  value       = aws_instance.api_server_1.public_ip
  description = "IP publica del API Server 1"
}

output "api_server_2_public_ip" {
  value       = aws_instance.api_server_2.public_ip
  description = "IP publica del API Server 2"
}

output "worker_public_ip" {
  value       = aws_instance.worker.public_ip
  description = "IP publica del Worker"
}

output "postgres_public_ip" {
  value       = aws_instance.postgres.public_ip
  description = "IP publica del PostgreSQL"
}

output "producer_public_ip" {
  value       = aws_instance.producer.public_ip
  description = "IP publica del Producer"
}

output "haproxy_url" {
  value       = "http://${aws_instance.haproxy.public_ip}/api/sensor-data"
  description = "URL del HAProxy para enviar datos de sensores"
}