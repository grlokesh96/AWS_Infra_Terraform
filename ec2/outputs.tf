output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.app_server.id
}

output "public_ip" {
  description = "EC2 public IP"
  value       = aws_instance.app_server.public_ip
}

output "private_ip" {
  description = "EC2 private IP"
  value       = aws_instance.app_server.private_ip
}

output "instance_type" {
  description = "EC2 instance type"
  value       = aws_instance.app_server.instance_type
}
