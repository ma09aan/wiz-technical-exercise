variable "project_name" {
  description = "Project name prefix for IAM resources"
  type        = string
}

# variable "eks_cluster_name" {
#   description = "Name of the EKS cluster, used for specific IAM policies if needed (e.g., OIDC provider)"
#   type        = string
#   default     = "" # Optional, might not be needed for these basic roles
# }

