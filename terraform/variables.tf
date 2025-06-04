variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1" # Choose your region
}

variable "project_name" {
  description = "A unique name for the project to prefix resources"
  type        = string
  default     = "wizexercise"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "mongodb_ami_id" {
  description = "AMI ID for an outdated Linux version for MongoDB VM. Find one in your region."
  type        = string
  default     = "" # e.g., "ami-0abcdef1234567890" - User must provide this
  # Example for Ubuntu 16.04 in us-east-1 (check current availability and choose an appropriate one): "ami-0520e698dd374b414"
  # It's better to leave this blank and require the user to find a suitable AMI.
  # Or use a data source to find one, but "outdated" is subjective.
}

variable "mongodb_instance_type" {
  description = "Instance type for MongoDB VM"
  type        = string
  default     = "t2.micro"
}

variable "db_username" {
  description = "Database username for MongoDB"
  type        = string
  default     = "wizadmin"
}

variable "db_password" {
  description = "Database password for MongoDB"
  type        = string
  sensitive   = true
  # User should provide this via a .tfvars file or environment variable for security
  # e.g., TF_VAR_db_password
}
