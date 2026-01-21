################################################################################
# Security Module Outputs
################################################################################

output "app_sg_id" {
  description = "Application security group ID"
  value       = aws_security_group.app.id
}

output "db_sg_id" {
  description = "Database security group ID"
  value       = aws_security_group.db.id
}

output "app_sg_name" {
  description = "Application security group name"
  value       = aws_security_group.app.name
}

output "db_sg_name" {
  description = "Database security group name"
  value       = aws_security_group.db.name
}

