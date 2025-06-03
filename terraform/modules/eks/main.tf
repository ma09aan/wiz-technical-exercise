# ./modules/eks/main.tf
# This is a simplified EKS cluster setup.
# For production, consider using the official AWS EKS Terraform module:
# [https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest)

resource "aws_eks_cluster" "main" {
  name     = "${var.project_name}-eks-cluster" # Named\\\ the cluster using a project prefix (e.g., myapp-eks-cluster
  role_arn = var.eks_cluster_role_arn
  version  = var.eks_cluster_version # e.g., "1.27"

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = true # Keep control plane private if possible
    endpoint_public_access  = true # Allow public access for kubectl from outside VPC for exercise
    # For production, restrict public_access_cidrs = ["YOUR_IP/32"]
    # public_access_cidrs = ["0.0.0.0/0"] # For exercise simplicity if needed
  }

  # Ensure IAM role for EKS Cluster is created before the cluster
  depends_on = [
    # aws_iam_role_policy_attachment.eks_cluster_policy, # Assuming these are defined in the IAM module
    # aws_iam_role_policy_attachment.eks_vpc_resource_controller,
  ]
  tags = { Name = "${var.project_name}-eks-cluster" }
}

resource "aws_eks_node_group" "general" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.project_name}-nodegroup"
  node_role_arn   = var.eks_nodegroup_role_arn
  subnet_ids      = var.private_subnet_ids # Worker nodes in private subnets
  instance_types  = var.eks_node_instance_types # e.g., ["t3.medium"]
  disk_size       = var.eks_node_disk_size      # e.g., 20 GB

  scaling_config {
    desired_size = var.eks_node_desired_size
    max_size     = var.eks_node_max_size
    min_size     = var.eks_node_min_size
  }

  # Optional: For SSH access to nodes (requires an EC2 key pair)
  # remote_access {
  #   ec2_ssh_key = var.ec2_ssh_key_name
  # }

  # Ensure IAM role for EKS Node Group and its policies are created first
  depends_on = [
    # aws_iam_role_policy_attachment.eks_worker_node_policy,
    # aws_iam_role_policy_attachment.eks_cni_policy,
    # aws_iam_role_policy_attachment.ecr_read_only_policy,
  ]
  tags = { Name = "${var.project_name}-eks-nodegroup" }
}

# Data source to get the security group created by EKS for the node group.
# This is a common way to retrieve it if not using a comprehensive EKS module that outputs it directly.
# Note: This might take a moment for the SG to be tagged and discoverable after node group creation.
# It's often more reliable if the EKS module itself provides this output.
# data "aws_security_group" "eks_worker_node_sg" {
#   # Wait for the node group to be created
#   depends_on = [aws_eks_node_group.general]

#   filter {
#     name   = "tag:eks:cluster-name"
#     values = [aws_eks_cluster.main.name]
#   }
#   # EKS often creates a "shared node security group" or one per node group.
#   # You might need to adjust filters if multiple SGs match.
#   # Look for a security group description like "EKS created security group for node group..."
#   # Or a specific tag that identifies the primary worker node SG.
#   # This is a common point of difficulty without a full EKS module.
#   # An alternative is to look at `aws_eks_node_group.general.resources[0].remote_access_security_group_id`
#   # if remote_access is configured, but that's for SSH, not necessarily the main SG for pod traffic.
#   # For this exercise, if this data source is unreliable, you might have to:
#   # 1. Manually find the SG ID after `terraform apply` and update MongoDB's SG.
#   # 2. Allow broader access from private subnets to MongoDB initially.
#   # 3. Use the `aws_eks_cluster` `vpc_config.cluster_security_group_id` if that's relevant for your CNI.

#   # A more direct way if the node group creates a specific SG and you know its naming pattern or tags:
#   # For example, if the node group itself gets a security group ID associated directly:
#   # (This is hypothetical, check actual attributes of aws_eks_node_group)
#   # value = aws_eks_node_group.general.primary_security_group_id
#   #
#   # The most reliable method is often to use an EKS module that correctly exports this.
#   # For now, we'll assume you might need to manually adjust the MongoDB SG or use a broader rule.
#   # This data source is an attempt to automate it.
#   # If it fails, comment it out and the output, and handle SG manually or with broader rules.
#   #
#   # A common tag for the primary SG used by nodes is:
#   # filter {
#   #   name = "tag:Name"
#   #   values = ["eks-cluster-sg-${aws_eks_cluster.main.name}-*"] # Pattern might vary
#   # }
#   # Or check the launch template associated with the node group.
#   #
#   # Using the cluster's shared security group as a fallback (might not be the one nodes use for egress)
#   # id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
# }

