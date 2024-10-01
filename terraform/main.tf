provider "aws" {
  region = "us-east-1"  
}

# Criar o cluster EKS 
resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = var.cluster_role_arn

  version  = "1.31"  # Versão do Kubernetes
  bootstrap_self_managed_addons = false
  vpc_config {
    subnet_ids = var.subnet_ids
  }
}

# Definindo o papel IAM para o grupo de nodes do EKS
resource "aws_iam_role" "node_role" {
  name               = "node-role"
  assume_role_policy = data.aws_iam_policy_document.eks_assume_role_policy.json
}

# Criando a política do role
data "aws_iam_policy_document" "eks_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }

  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"] 
    }
  }
}


# Anexando as políticas
resource "aws_iam_role_policy_attachment" "worker_node_policy" {
  role       = aws_iam_role.node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "cni_policy" {
  role       = aws_iam_role.node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "ec2_policy" {
  role       = aws_iam_role.node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

# Criar o grupo de nós
resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "new-node-group"
  node_role_arn   = aws_iam_role.node_role.arn 
  subnet_ids      = var.subnet_ids

  instance_types  = [var.instance_type]  # Deve ser uma lista

  scaling_config {
    desired_size = var.desired_size
    min_size     = var.min_size
    max_size     = var.max_size
  }

  depends_on = [aws_eks_cluster.this]
}

# Configuração do provider Kubernetes
provider "kubernetes" {
  host                   = aws_eks_cluster.this.endpoint
  token                  = data.aws_eks_cluster_auth.cluster.token
  cluster_ca_certificate = base64decode(aws_eks_cluster.this.certificate_authority[0].data)
}

# Aplica as configurações do Kubernetes
resource "null_resource" "k8s_apply" {
  provisioner "local-exec" {
    command = "kubectl apply -f k8s/"
  }

  triggers = {
    always_run = "${timestamp()}"  # Força a execução sempre que o Terraform é aplicado
  }

  depends_on = [aws_eks_node_group.this]
}

data "aws_eks_cluster_auth" "cluster" {
  name = aws_eks_cluster.this.name
}
