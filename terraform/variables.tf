variable "cluster_name" {
  description = "Nome do cluster EKS"
  type        = string
}

variable "cluster_role_arn" {
  description = "ARN do IAM Role do cluster EKS"
  type        = string
}

variable "node_role_arn" {
  description = "ARN do IAM Role para os nós"
  type        = string
}

variable "desired_size" {
  description = "Número desejado de nós"
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Número máximo de nós"
  type        = number
  default     = 3
}

variable "min_size" {
  description = "Número mínimo de nós"
  type        = number
  default     = 1
}

variable "subnet_ids" {
  description = "Subnets para o grupo de nós"
  type        = list(string)
}

variable "instance_type" {
  description = "Tipo de instância para o grupo de nós"
  type        = string
  default     = "t3.medium"
}
