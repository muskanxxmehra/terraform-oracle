################################################################################
# EC2 DB Module Variables - Oracle XE 21c
################################################################################

variable "ami_id" {
  description = "AMI ID (Oracle Linux 8 or Amazon Linux 2 recommended)"
  type        = string
}

variable "instance_type" {
  description = "Instance type (minimum t3.medium for Oracle XE)"
  type        = string
  default     = "t3.medium"
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

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "root_volume_size" {
  description = "Root volume size in GB (minimum 20GB for Oracle XE)"
  type        = number
  default     = 30
}

variable "db_name" {
  description = "Database/Schema name"
  type        = string
  default     = "appdb"
}

variable "db_user" {
  description = "Database application user"
  type        = string
  default     = "appuser"
}

variable "db_password" {
  description = "Database password (for SYS and application user)"
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}

