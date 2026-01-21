################################################################################
# EC2 App Module Variables - Oracle XE Client
################################################################################

variable "ami_id" {
  description = "AMI ID"
  type        = string
}

variable "instance_type" {
  description = "Instance type"
  type        = string
  default     = "t2.micro"
}

variable "subnet_id" {
  description = "Subnet ID"
  type        = string
}

variable "security_group_id" {
  description = "Security group ID"
  type        = string
}

variable "key_name" {
  description = "SSH key name"
  type        = string
}

variable "iam_instance_profile" {
  description = "IAM instance profile name"
  type        = string
}

variable "app_name" {
  description = "Application name"
  type        = string
  default     = "flask-app"
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "root_volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 8
}

variable "create_eip" {
  description = "Create Elastic IP"
  type        = bool
  default     = false
}

variable "app_port" {
  description = "Application port"
  type        = number
  default     = 5000
}

#------------------------------------------------------------------------------
# Oracle Database Connection Variables
#------------------------------------------------------------------------------

variable "db_host" {
  description = "Oracle database host (private IP)"
  type        = string
}

variable "db_port" {
  description = "Oracle listener port"
  type        = number
  default     = 1521
}

variable "db_service" {
  description = "Oracle service name"
  type        = string
  default     = "XEPDB1"
}

variable "db_user" {
  description = "Oracle database user"
  type        = string
  default     = "appuser"
}

variable "db_password" {
  description = "Oracle database password"
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}

