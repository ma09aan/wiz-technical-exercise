variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "aws_region" {
  description = "AWS Region"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC where EKS will be deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for EKS control plane and worker nodes"
  type        = list(string)
}

variable "eks_cluster_role_arn" {
  description = "IAM Role ARN for the EKS cluster"
  type        = string
}

variable "eks_nodegroup_role_arn" {
  description = "IAM Role ARN for the EKS worker nodes"
  type        = string
}

variable "eks_cluster_version" {
  description = "Desired Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.27"
}

variable "eks_node_instance_types" {
  description = "List of instance types for EKS worker nodes"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "eks_node_disk_size" {
  description = "Disk size (in GiB) for EKS worker nodes"
  type        = number
  default     = 20
}

variable "eks_node_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "eks_node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 3
}

variable "eks_node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

# variable "ec2_ssh_key_name" {
#   description = "Name of the EC2 key pair for SSH access to worker nodes (optional)"
#   type        = string
#   default     = ""
# }

