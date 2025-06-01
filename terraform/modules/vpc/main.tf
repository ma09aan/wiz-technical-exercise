# ./modules/vpc/main.tf
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.project_name}-igw"
  }
}

resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true # For public subnets
  tags = {
    Name = "${var.project_name}-public-subnet-${count.index + 1}"
  }
}

resource "aws_subnet" "private" {
  count                   = length(var.private_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false
  tags = {
    Name = "${var.project_name}-private-subnet-${count.index + 1}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = { Name = "${var.project_name}-public-rt" }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# NAT Gateway for private subnets (if EKS nodes need outbound internet for image pulls etc.)
resource "aws_eip" "nat" {
  count = length(var.private_subnet_cidrs) > 0 ? 1 : 0 # Create only if private subnets exist
  # vpc   = true # For VPC EIP, use domain = "vpc" in newer provider versions
  domain = "vpc"
  tags  = { Name = "${var.project_name}-nat-eip" }
}

resource "aws_nat_gateway" "nat" {
  count         = length(var.private_subnet_cidrs) > 0 ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id # Place NAT GW in a public subnet
  tags = { Name = "${var.project_name}-nat-gw" }
  depends_on = [aws_internet_gateway.gw]
}

resource "aws_route_table" "private" {
  count  = length(var.private_subnet_cidrs) > 0 ? 1 : 0
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[0].id
  }
  tags = { Name = "${var.project_name}-private-rt" }
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[0].id
}

# Security Group for MongoDB VM
resource "aws_security_group" "mongodb_sg" {
  name        = "${var.project_name}-mongodb-sg"
  description = "Allow SSH and MongoDB traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from Internet (Intentional Weakness)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # !! INTENTIONAL WEAKNESS !!
  }

  ingress {
    description      = "MongoDB from K8s Worker Nodes (placeholder)"
    from_port        = 27017 # Default MongoDB port
    to_port          = 27017
    protocol         = "tcp"
    # This should be updated to use the EKS worker node security group ID.
    # For now, allowing from the entire VPC for simplicity, then refine.
    # Or, if k8s_worker_sg_id is passed as a variable to this module:
    # security_groups = var.k8s_worker_sg_id != "" ? [var.k8s_worker_sg_id] : null
    cidr_blocks      = var.k8s_worker_sg_id == "" ? [var.vpc_cidr] : null # Allow from VPC if SG not provided
    security_groups  = var.k8s_worker_sg_id != "" ? [var.k8s_worker_sg_id] : null
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${var.project_name}-mongodb-sg" }
}
