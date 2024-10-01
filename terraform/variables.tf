variable "cluster_name" {
  description = "Nome do cluster EKS"
  type        = string
}

variable "cluster_role_arn" {
  description = "ARN do papel IAM para o cluster EKS"
  type        = string
}

variable "node_role_arn" {
  description = "ARN do papel IAM para o grupo de nós"
  type        = string
}

variable "subnet_ids" {
  description = "IDs das sub-redes para o EKS"
  type        = list(string)
}

variable "instance_type" {
  description = "Tipo de instância para os nós"
  type        = string
  default     = "t3.micro"  # Tipo de instância micro
}

variable "desired_size" {
  description = "Número desejado de nós"
  type        = number
}

variable "min_size" {
  description = "Número mínimo de nós"
  type        = number
}

variable "max_size" {
  description = "Número máximo de nós"
  type        = number
}
