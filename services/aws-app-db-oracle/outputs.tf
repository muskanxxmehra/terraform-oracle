################################################################################
# AWS App + Oracle XE DB Service - Outputs
################################################################################

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "app_server_public_ip" {
  description = "Public IP of the application server"
  value       = module.app.public_ip
}

output "app_server_private_ip" {
  description = "Private IP of the application server"
  value       = module.app.private_ip
}

output "db_server_public_ip" {
  description = "Public IP of the Oracle XE database server"
  value       = module.db.public_ip
}

output "db_server_private_ip" {
  description = "Private IP of the Oracle XE database server"
  value       = module.db.private_ip
}

output "oracle_connect_string" {
  description = "Oracle connection string"
  value       = module.db.oracle_connect_string
}

output "oracle_jdbc_url" {
  description = "Oracle JDBC URL for Java applications"
  value       = module.db.oracle_jdbc_url
}

output "db_service" {
  description = "Oracle service name"
  value       = var.db_service
}

output "db_user" {
  description = "Oracle database username"
  value       = var.db_user
}

output "app_url" {
  description = "Application URL"
  value       = "http://${module.app.public_ip}:${var.app_port}"
}

#------------------------------------------------------------------------------
# Connection Commands
#------------------------------------------------------------------------------

output "ssh_commands" {
  description = "SSH commands to connect to servers"
  value       = <<-EOT

=== SSH Commands ===

App Server:
  ssh -i ~/.ssh/${var.key_name}.pem ec2-user@${module.app.public_ip}

Oracle DB Server:
  ssh -i ~/.ssh/${var.key_name}.pem ec2-user@${module.db.public_ip}

=== Application ===

Web UI:
  http://${module.app.public_ip}:${var.app_port}

API Endpoints:
  http://${module.app.public_ip}:${var.app_port}/api/users
  http://${module.app.public_ip}:${var.app_port}/api/orders
  http://${module.app.public_ip}:${var.app_port}/api/db-info
  http://${module.app.public_ip}:${var.app_port}/health

=== Oracle Database ===

Connection String:
  ${var.db_user}/<password>@${module.db.private_ip}:1521/${var.db_service}

JDBC URL:
  jdbc:oracle:thin:@${module.db.private_ip}:1521/${var.db_service}

Python oracledb DSN:
  ${module.db.private_ip}:1521/${var.db_service}

SQL*Plus (from DB server):
  sqlplus ${var.db_user}/<password>@XEPDB1

Oracle EM Express (web-based admin):
  https://${module.db.public_ip}:5500/em

=== Troubleshooting ===

Check user_data logs:
  ssh -i ~/.ssh/${var.key_name}.pem ec2-user@<IP> "sudo cat /var/log/user-data.log"

Check services:
  ssh -i ~/.ssh/${var.key_name}.pem ec2-user@${module.app.public_ip} "sudo systemctl status flask-app"
  ssh -i ~/.ssh/${var.key_name}.pem ec2-user@${module.db.public_ip} "sudo systemctl status oracle-xe-21c"

Check Oracle Listener:
  ssh -i ~/.ssh/${var.key_name}.pem ec2-user@${module.db.public_ip} "sudo su - oracle -c 'lsnrctl status'"

Check Oracle Database:
  ssh -i ~/.ssh/${var.key_name}.pem ec2-user@${module.db.public_ip} "sudo su - oracle -c 'sqlplus / as sysdba <<< \"SELECT status FROM v\\$instance;\"'"

EOT
}

#------------------------------------------------------------------------------
# Data Migration Info
#------------------------------------------------------------------------------

output "data_export_info" {
  description = "Information for data export/import"
  value       = <<-EOT

=== Oracle Data Export ===

Export using SQL*Plus (from DB server):
  ssh -i ~/.ssh/${var.key_name}.pem ec2-user@${module.db.public_ip}
  
  sudo su - oracle
  sqlplus ${var.db_user}/<password>@XEPDB1
  
  -- Export to CSV
  SET MARKUP CSV ON
  SPOOL /tmp/users.csv
  SELECT * FROM users;
  SPOOL OFF
  
  SPOOL /tmp/orders.csv
  SELECT * FROM orders;
  SPOOL OFF

Export using Data Pump (recommended for large datasets):
  expdp ${var.db_user}/<password>@XEPDB1 tables=users,orders directory=DATA_PUMP_DIR dumpfile=export.dmp

Download CSV files:
  scp -i ~/.ssh/${var.key_name}.pem ec2-user@${module.db.public_ip}:/tmp/users.csv .
  scp -i ~/.ssh/${var.key_name}.pem ec2-user@${module.db.public_ip}:/tmp/orders.csv .

=== Oracle Cloud Migration ===

For migration to Oracle Autonomous Database:
1. Export data using Data Pump or CSV
2. Upload to OCI Object Storage
3. Import using DBMS_CLOUD.COPY_DATA or Data Pump import

EOT
}

