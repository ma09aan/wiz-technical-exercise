output "mongodb_ec2_public_ip" {
  description = "Public IP address of the MongoDB EC2 instance."
  value       = module.ec2_mongodb.mongodb_public_ip_output # Ensure ec2_mongodb module outputs this
}

output "s3_backup_bucket_name" {
  description = "Name of the S3 bucket for database backups."
  value       = module.s3_backups.bucket_name_output # Ensure s3_backups module outputs thhis
}

output "eks_cluster_endpoint" {
  description = "Endpoint for your EKS Kubernetes API server."
  value       = module.eks.cluster_endpoint_output # Ensure eks module outputs this
}

output "eks_cluster_name" {
  description = "EKS Cluster name."
  value       = module.eks.cluster_name_output # Ensure eks module outputs this
}

output "eks_cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the EKS cluster."
  value       = module.eks.cluster_ca_certificate_output # Ensure eks module outputs this
  sensitive   = true
}

output "ecr_repository_url" {
  description = "URL of the ECR repository for the application."
  value       = aws_ecr_repository.app_repo.repository_url
}

output "application_load_balancer_hostname" {
  description = "Hostname of the Load Balancer for the web application. (Note: This will be available after K8s service deployment)"
  value       = "To be determined by Kubernetes Service type LoadBalancer. Check 'kubectl get svc wizapp-service -n wizapp'"
}

# In your root outputs.tf (e.g., terraform/outputs.tf)
output "mongodb_module_resolved_path" {
  value = module.ec2_mongodb.actual_module_path
}
