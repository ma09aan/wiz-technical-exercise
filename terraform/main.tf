
# Specify Terraform configuration needs AWS, Kubernetes, Helm, and Random providers
# operator allows patch-level version upgrades within the same major version.


terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Check for latest stable version
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20" # Check for latest stable version
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.10" # Check for latest stable versions
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5.0"
    }
  }
  # Optional: Configure S3 backend for state file management (highly recommended)
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket-name" # Create this S3 bucket first
  #   key            = "wiz-exercise/terraform.tfstate"
  #   region         = "your-aws-region" # Should match var.aws_region
  #   encrypt        = true
  #   dynamodb_table = "your-terraform-state-lock-table" # Create this DynamoDB table for locking
  # }
}


# Configures the AWS provider using a variable for the region.

provider "aws" {
  region = var.aws_region
  # Configure AWS credentials via environment variables or AWS CLI profiles
}

# Data source to get availability zones

data "aws_availability_zones" "available" {
  state = "available"
}

# Generate a random suffix (used for uniqueness).

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# We want to want to create an ECR repository for your app
# MUTABLE allows you to overwrite existing image tags, which can be both helpful and risky
# It speeds up pipelines and reduces storage cost
# Use IMMUTABLE in production environments


resource "aws_ecr_repository" "app_repo" {
  name                 = "${var.project_name}-app-repo"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# Call your Terraform modules

module "vpc" {
  source = "./modules/vpc"

  project_name = var.project_name
  aws_region   = var.aws_region
  vpc_cidr     = var.vpc_cidr
  public_subnet_cidrs = [
    cidrsubnet(var.vpc_cidr, 8, 0), # Takes your base CIDR block (e.g. 10.0.0.0/16);Creates a subnet with a /24 mask (by adding 8 bits);Returns the first subnet (10.0.0.0/24)
    cidrsubnet(var.vpc_cidr, 8, 1)  # 10.0.1.0/24 
  ]
  private_subnet_cidrs = [
    cidrsubnet(var.vpc_cidr, 8, 2), # 10.0.2.0/24
    cidrsubnet(var.vpc_cidr, 8, 3) # 10.0.3.0/24
  ]
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2) # Use 2 AZs
}

module "iam_roles" {
  source = "./modules/iam"

  project_name    = var.project_name
  # eks_cluster_name = module.eks.cluster_name # This creates a circular dependency if EKS module needs IAM roles first.
                                            # Pass necessary identifiers if roles are tightly coupled, or create roles first.
}

module "s3_backups" {
  source = "./modules/s3_backups"

  bucket_name  = "${var.project_name}-db-backups-${random_id.bucket_suffix.hex}"
  project_name = var.project_name
}


# Terraform tries to build everything in parallel as long as it thinks it has what it needs
# enforce order to say do not start creating the ec2_mongodb module until all of these modules have been successfully created
# Ensure the VPC, subnets, and security groups exist.
# Ensure IAM instance profiles and permissions are ready.
# Ensure the S3 bucket for database backups is available
# Ensure Kubernetes cluster exists, likely for interconnectivity (e.g. allowing pods to reach MongoDB).



module "eks" {
  source = "./modules/eks"
  depends_on = [module.vpc, module.iam_roles] # Ensure VPC and IAM roles are created first

  project_name          = var.project_name
  aws_region            = var.aws_region
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnets_ids_output # Ensure VPC module outputs this
  eks_cluster_role_arn  = module.iam_roles.eks_cluster_role_arn_output # Ensure IAM module outputs this
  eks_nodegroup_role_arn = module.iam_roles.eks_nodegroup_role_arn_output # Ensure IAM module outputs this
}

module "ec2_mongodb" {
  source = "./modules/ec2_mongodb"
  depends_on = [module.vpc, module.iam_roles, module.s3_backups, module.eks] # Ensure dependencies are met

  project_name        = var.project_name
  aws_region          = var.aws_region
  mongodb_ami_id      = var.mongodb_ami_id # Specify an outdated AMI
  instance_type       = var.mongodb_instance_type
  subnet_id           = module.vpc.public_subnets_ids_output[0] # Ensure VPC module outputs this
  vpc_security_group_ids = [module.vpc.mongodb_sg_id_output] # Ensure VPC module outputs this
  iam_instance_profile_name = module.iam_roles.ec2_mongodb_instance_profile_name_output # Ensure IAM module outputs this
  s3_backup_bucket_name = module.s3_backups.bucket_name_output # Ensure S3 module outputs this
  db_username         = var.db_username
  db_password         = var.db_password # Pass as sensitive variable
  # Pass the EKS worker node security group ID to allow DB connections
  # This requires careful handling of dependencies or using data sources.
  # For simplicity, the VPC module's MongoDB SG might initially allow broader access from private subnets,
  # then you could refine it. Or, EKS module needs to output its worker SG ID.
  k8s_worker_sg_id    = module.eks.worker_security_group_id_output # Ensure EKS module outputs this
}
