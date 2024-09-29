provider "aws" {
  region = "us-east-1"
}

# Data source to get available availability zones
data "aws_availability_zones" "available" {}

# Data source to check for existing VPC
data "aws_vpc" "existing" {
  filter {
    name   = "tag:Name"
    values = ["eks-vpc"]
  }
}

# Create VPC if not exists
resource "aws_vpc" "main" {
  count = length(data.aws_vpc.existing.id) == 0 ? 1 : 0  # Use 'id' here

  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "eks-vpc"
  }
}

# Create public subnets
resource "aws_subnet" "public" {
  count = 2
  vpc_id = length(data.aws_vpc.existing.id) > 0 ? data.aws_vpc.existing.id : aws_vpc.main[0].id  # Use 'id'

  cidr_block = "10.0.${count.index}.0/24"
  availability_zone = element(data.aws_availability_zones.available.names, count.index)

  tags = {
    Name = "public-subnet-${count.index}"
    Tier  = "public"
  }
}

# Create private subnets
resource "aws_subnet" "private" {
  count = 2
  vpc_id = length(data.aws_vpc.existing.id) > 0 ? data.aws_vpc.existing.id : aws_vpc.main[0].id  # Use 'id'

  cidr_block = "10.0.${count.index + 2}.0/24"
  availability_zone = element(data.aws_availability_zones.available.names, count.index)

  tags = {
    Name = "private-subnet-${count.index}"
    Tier  = "private"
  }
}

# Create an internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = length(data.aws_vpc.existing.id) > 0 ? data.aws_vpc.existing.id : aws_vpc.main[0].id  # Use 'id'

  tags = {
    Name = "eks-igw"
  }
}

# Create a route table for the public subnet
resource "aws_route_table" "public" {
  vpc_id = length(data.aws_vpc.existing.id) > 0 ? data.aws_vpc.existing.id : aws_vpc.main[0].id  # Use 'id'

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-route-table"
  }
}

# Associate the route table with public subnets
resource "aws_route_table_association" "public" {
  count = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Create IAM role for EKS
resource "aws_iam_role" "eks_role" {
  name = "eks-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_policy_attach" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_role.name
}

# Create the EKS cluster
resource "aws_eks_cluster" "eks" {
  name     = "eks-cluster"
  role_arn = aws_iam_role.eks_role.arn

  vpc_config {
    subnet_ids = [
      aws_subnet.private[0].id,
      aws_subnet.private[1].id,
    ]
  }

  depends_on = [aws_iam_role_policy_attachment.eks_policy_attach]
}

# Create IAM role for Fargate
resource "aws_iam_role" "eks_fargate_role" {
  name = "eks-fargate-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "eks-fargate-pods.amazonaws.com"  # Service Principal for Fargate
        },
      },
    ],
  })
}

resource "aws_iam_role_policy_attachment" "fargate_policy_attach" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
  role       = aws_iam_role.eks_fargate_role.name
}

# Create the Fargate profile
resource "aws_eks_fargate_profile" "fargate_profile" {
  cluster_name           = aws_eks_cluster.eks.name
  fargate_profile_name   = "my-fargate-profile"
  pod_execution_role_arn = aws_iam_role.eks_fargate_role.arn
  subnet_ids             = [
    aws_subnet.private[0].id,
    aws_subnet.private[1].id,
  ]

  selector {
    namespace = "default"
  }

  depends_on = [aws_eks_cluster.eks]
}
