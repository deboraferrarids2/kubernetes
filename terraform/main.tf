provider "aws" {
  region = "us-east-1"
}

# Data source to get available availability zones
data "aws_availability_zones" "available" {}

# Data source para obter VPC existente ou criar se não existir
data "aws_vpc" "existing_vpc" {
  filter {
    name   = "tag:Name"
    values = ["eks-vpc"]
  }
}

resource "aws_vpc" "main" {
  count = length(data.aws_vpc.existing_vpc.id) == 0 ? 1 : 0

  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "eks-vpc"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Subnets públicas e privadas
resource "aws_subnet" "public" {
  count = 2
  vpc_id = coalesce(data.aws_vpc.existing_vpc.id, aws_vpc.main[0].id)
  cidr_block = "10.0.${count.index}.0/24"
  availability_zone = element(data.aws_availability_zones.available.names, count.index)

  tags = {
    Name = "public-subnet-${count.index}"
    Tier = "public"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_subnet" "private" {
  count = 2
  vpc_id = coalesce(data.aws_vpc.existing_vpc.id, aws_vpc.main[0].id)
  cidr_block = "10.0.${count.index + 2}.0/24"
  availability_zone = element(data.aws_availability_zones.available.names, count.index)

  tags = {
    Name = "private-subnet-${count.index}"
    Tier = "private"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Data source para verificar Internet Gateway
data "aws_internet_gateway" "existing_igw" {
  filter {
    name   = "tag:Name"
    values = ["eks-igw"]
  }
}

# Criar gateway de internet se não existir
resource "aws_internet_gateway" "igw" {
  count  = length(data.aws_internet_gateway.existing_igw.id) == 0 ? 1 : 0
  vpc_id = coalesce(data.aws_vpc.existing_vpc.id, aws_vpc.main[0].id)

  tags = {
    Name = "eks-igw"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Criar uma tabela de rotas para a subnet pública
resource "aws_route_table" "public" {
  vpc_id = coalesce(data.aws_vpc.existing_vpc.id, aws_vpc.main[0].id)

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = coalesce(data.aws_internet_gateway.existing_igw.id, aws_internet_gateway.igw[0].id)
  }

  tags = {
    Name = "public-route-table"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Associar a tabela de rotas às subnets públicas
resource "aws_route_table_association" "public" {
  count = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id

  lifecycle {
    prevent_destroy = true
  }
}

# Data source para verificar se o IAM Role para EKS já existe
data "aws_iam_role" "eks_role" {
  name = "eks-role"
}

resource "aws_iam_role" "eks_role" {
  count = length(data.aws_iam_role.eks_role.arn) == 0 ? 1 : 0

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

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_iam_role_policy_attachment" "eks_policy_attach" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = coalesce(data.aws_iam_role.eks_role.name, aws_iam_role.eks_role[0].name)
}

# Cluster EKS
resource "aws_eks_cluster" "eks" {
  name     = "eks-cluster"
  role_arn = coalesce(data.aws_iam_role.eks_role.arn, aws_iam_role.eks_role[0].arn)

  vpc_config {
    subnet_ids = [
      aws_subnet.private[0].id,
      aws_subnet.private[1].id,
    ]
  }

  depends_on = [aws_iam_role_policy_attachment.eks_policy_attach]
}

# Data source para verificar se o IAM Role para Fargate já existe
data "aws_iam_role" "eks_fargate_role" {
  name = "eks-fargate-role"
}

resource "aws_iam_role" "eks_fargate_role" {
  count = length(data.aws_iam_role.eks_fargate_role.arn) == 0 ? 1 : 0

  name = "eks-fargate-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "eks-fargate-pods.amazonaws.com"
        },
      },
    ],
  })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_iam_role_policy_attachment" "fargate_policy_attach" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
  role       = coalesce(data.aws_iam_role.eks_fargate_role.name, aws_iam_role.eks_fargate_role[0].name)
}

# Perfil de Fargate
resource "aws_eks_fargate_profile" "fargate_profile" {
  cluster_name           = aws_eks_cluster.eks.name
  fargate_profile_name   = "my-fargate-profile"
  pod_execution_role_arn = coalesce(data.aws_iam_role.eks_fargate_role.arn, aws_iam_role.eks_fargate_role[0].arn)
  subnet_ids             = [
    aws_subnet.private[0].id,
    aws_subnet.private[1].id,
  ]

  selector {
    namespace = "default"
  }

  depends_on = [aws_eks_cluster.eks]
}