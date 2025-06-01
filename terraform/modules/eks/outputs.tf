output "cluster_name_output" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint_output" {
  description = "Endpoint for the EKS cluster"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_ca_certificate_output" {
  description = "Base64 encoded certificate authority data for the EKS cluster"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

output "nodegroup_name_output" {
  description = "Name of the EKS node group"
  value       = aws_eks_node_group.general.node_group_name
}

# output "worker_security_group_id_output" {
#   description = "Security group ID of the EKS worker nodes. (This might be tricky to get accurately without a full EKS module, see notes in main.tf)"
#   # Attempting to use the data source. If this fails, this output will be problematic.
#   # value       = length(data.aws_security_group.eks_worker_node_sg) > 0 ? data.aws_security_group.eks_worker_node_sg[0].id : "Manually-Identify-EKS-Worker-SG"
#   # Fallback or if data source is commented:
#   value       = "Manually-Identify-EKS-Worker-SG-Or-Use-Broader-Rule-In-MongoDB-SG"
#   # If using the official EKS module, it would typically provide a reliable output for this.
# }


output "worker_security_group_id_output" {
  description = "Security group ID of the EKS worker nodes. (Manually identify or use broader rule)."
  # Since the data source is commented out, provide a placeholder string.
  value       = "sg-055f33ed6cff23ea9"
}

