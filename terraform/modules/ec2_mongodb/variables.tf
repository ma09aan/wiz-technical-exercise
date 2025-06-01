variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "aws_region" {
  description = "AWS Region"
  type        = string
}

variable "mongodb_ami_id" {
  description = "Specific AMI ID for the MongoDB instance (for outdated OS). If empty, a default recent AMI is used."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for MongoDB"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for the MongoDB EC2 instance"
  type        = string
}

variable "vpc_security_group_ids" {
  description = "List of VPC Security Group IDs for the MongoDB EC2 instance"
  type        = list(string)
}

variable "iam_instance_profile_name" {
  description = "IAM instance profile name for the MongoDB EC2 instance"
  type        = string
}

variable "s3_backup_bucket_name" {
  description = "Name of the S3 bucket for database backups"
  type        = string
}

variable "db_username" {
  description = "MongoDB username"
  type        = string
}

variable "db_password" {
  description = "MongoDB password"
  type        = string
  sensitive   = true
}

variable "k8s_worker_sg_id" {
  description = "Security Group ID of EKS worker nodes (optional, for SG rule reference)"
  type        = string
  default     = ""
}
