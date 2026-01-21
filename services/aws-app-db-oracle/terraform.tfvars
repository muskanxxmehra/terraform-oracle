################################################################################
# AWS App + Oracle XE DB Service - Example Variables
# Copy this file to terraform.tfvars and customize the values
################################################################################

#------------------------------------------------------------------------------
# General Settings
#------------------------------------------------------------------------------
aws_region   = "us-east-1"
project_name = "webapp-oracle-project"
environment  = "dev"

tags = {
  Owner      = "your-name"
  CostCenter = "your-cost-center"
}

#------------------------------------------------------------------------------
# Network Settings
#------------------------------------------------------------------------------
vpc_cidr           = "10.0.0.0/16"
public_subnet_cidr = "10.0.1.0/24"

#------------------------------------------------------------------------------
# Security Settings
#------------------------------------------------------------------------------
# REQUIRED: Your SSH key pair name (must exist in AWS)
key_name = "your-key-pair-name"

# Restrict SSH access to your IP (recommended)
ssh_allowed_cidr = ["0.0.0.0/0"]  # Change to your IP: ["x.x.x.x/32"]

#------------------------------------------------------------------------------
# Application Server Settings
#------------------------------------------------------------------------------
app_name          = "flask-oracle-app"
app_instance_type = "t2.micro"
app_volume_size   = 8
create_app_eip    = false
app_port          = 5000

#------------------------------------------------------------------------------
# Oracle XE Database Server Settings
#------------------------------------------------------------------------------
# IMPORTANT: Oracle XE has minimum requirements!
# - Instance: t3.medium or larger (2 vCPU, 4GB RAM minimum)
# - Storage: 20GB minimum

use_oracle_linux  = true           # Use Oracle Linux 8 (recommended)
db_instance_type  = "t3.medium"    # Minimum for Oracle XE
db_volume_size    = 30             # 20GB minimum, 30GB recommended
db_port           = 1521           # Oracle Listener port
db_service        = "XEPDB1"       # Oracle XE pluggable database service

# Database credentials
db_user = "appuser"

# Add this line (uncomment and set your password)
db_password = "Azalio@123"

# REQUIRED: Set in Terraform Cloud or via environment variable
# db_password = "YourSecurePassword123"
# 
# Password requirements:
# - Minimum 8 characters
# - At least one uppercase letter
# - At least one lowercase letter  
# - At least one number
#
# Set via environment variable (recommended):
# export TF_VAR_db_password="YourSecurePassword123"

