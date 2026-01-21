################################################################################
# EC2 DB Module Outputs - Oracle XE 21c
################################################################################

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.db.id
}

output "public_ip" {
  description = "Public IP address"
  value       = aws_instance.db.public_ip
}

output "private_ip" {
  description = "Private IP address"
  value       = aws_instance.db.private_ip
}

output "oracle_connect_string" {
  description = "Oracle connection string"
  value       = "${aws_instance.db.private_ip}:1521/XEPDB1"
}

output "oracle_jdbc_url" {
  description = "Oracle JDBC URL"
  value       = "jdbc:oracle:thin:@${aws_instance.db.private_ip}:1521/XEPDB1"
}

