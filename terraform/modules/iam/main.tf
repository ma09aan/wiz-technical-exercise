# ./modules/iam/main.tf

# IAM Role for EC2 MongoDB Instance (Overly Permissive - Intentional Weakness)
resource "aws_iam_role" "ec2_mongodb_role" {
  name = "${var.project_name}-ec2-mongodb-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
  tags = { Name = "${var.project_name}-ec2-mongodb-role" }
}

# !! INTENTIONAL WEAKNESS: Overly permissive policies !!
resource "aws_iam_role_policy_attachment" "ec2_mongodb_s3_full_access" {
  role       = aws_iam_role.ec2_mongodb_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess" # Example of overly permissive
}
resource "aws_iam_role_policy_attachment" "ec2_mongodb_ec2_full_access" {
  role       = aws_iam_role.ec2_mongodb_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess" # Another example
}
# Add more permissive policies as per the exercise's intent, e.g., broad network config, etc.
# resource "aws_iam_role_policy_attachment" "ec2_mongodb_admin_access" {
#   role       = aws_iam_role.ec2_mongodb_role.name
#   policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess" # Extreme example for exercise
# }


resource "aws_iam_instance_profile" "ec2_mongodb_profile" {
  name = "${var.project_name}-ec2-mongodb-profile"
  role = aws_iam_role.ec2_mongodb_role.name
}

# IAM Role for EKS Cluster
resource "aws_iam_role" "eks_cluster_role" {
  name = "${var.project_name}-eks-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = { Service = "eks.amazonaws.com" }
    }]
  })
  tags = { Name = "${var.project_name}-eks-cluster-role" }
}
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" { # AmazonEKSClusterPolicy
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}
resource "aws_iam_role_policy_attachment" "eks_service_policy" { # AmazonEKSServicePolicy (might be needed by some versions/features)
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy" # Check if this is still best practice or if ClusterPolicy covers it
  role       = aws_iam_role.eks_cluster_role.name
}
# Required for EKS to manage VPC resources like ENIs for Load Balancers, etc.
# resource "aws_iam_role_policy_attachment" "eks_vpc_resource_controller" {
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
#   role       = aws_iam_role.eks_cluster_role.name
# }


# IAM Role for EKS Node Group
resource "aws_iam_role" "eks_nodegroup_role" {
  name = "${var.project_name}-eks-nodegroup-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
  tags = { Name = "${var.project_name}-eks-nodegroup-role" }
}
resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" { # AmazonEKSWorkerNodePolicy
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_nodegroup_role.name
}
resource "aws_iam_role_policy_attachment" "eks_cni_policy" { # AmazonEKS_CNI_Policy
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_nodegroup_role.name
}
resource "aws_iam_role_policy_attachment" "ecr_read_only_policy" { # AmazonEC2ContainerRegistryReadOnly
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_nodegroup_role.name
}
# Add AmazonSSMManagedInstanceCore if you want to use Session Manager for nodes
resource "aws_iam_role_policy_attachment" "ssm_core_policy" { # AmazonSSMManagedInstanceCore
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.eks_nodegroup_role.name
}

