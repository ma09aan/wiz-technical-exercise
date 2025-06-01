output "ec2_mongodb_instance_profile_name_output" {
  description = "Name of the IAM instance profile for the MongoDB EC2 instance"
  value       = aws_iam_instance_profile.ec2_mongodb_profile.name
}

output "eks_cluster_role_arn_output" {
  description = "ARN of the IAM role for the EKS cluster"
  value       = aws_iam_role.eks_cluster_role.arn
}

output "eks_nodegroup_role_arn_output" {
  description = "ARN of the IAM role for the EKS worker nodes"
  value       = aws_iam_role.eks_nodegroup_role.arn
}

