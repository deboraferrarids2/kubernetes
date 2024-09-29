output "vpc_id" {
  value = length(data.aws_vpc.existing.id) > 0 ? data.aws_vpc.existing.id : aws_vpc.main[0].id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "eks_cluster_name" {
  value = aws_eks_cluster.eks.name
}

output "eks_cluster_endpoint" {
  value = aws_eks_cluster.eks.endpoint
}

output "eks_cluster_arn" {
  value = aws_eks_cluster.eks.arn
}

output "fargate_profile_name" {
  value = aws_eks_fargate_profile.fargate_profile.fargate_profile_name
}
