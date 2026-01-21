################################################################################
# EC2 App Module Outputs
################################################################################

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.app.id
}

output "public_ip" {
  description = "Public IP address"
  value       = aws_instance.app.public_ip
}

output "private_ip" {
  description = "Private IP address"
  value       = aws_instance.app.private_ip
}

output "elastic_ip" {
  description = "Elastic IP (if created)"
  value       = var.create_eip ? aws_eip.app[0].public_ip : null
}

output "app_url" {
  description = "Application URL"
  value       = "http://${aws_instance.app.public_ip}:${var.app_port}"
}

