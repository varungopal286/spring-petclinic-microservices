output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = module.eks.cluster_endpoint
}

output "ecr_registry" {
  description = "ECR registry base URL"
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com"
}

output "alb_controller_role_arn" {
  description = "IAM role ARN for ALB controller — needed in Day 4"
  value       = module.alb_controller_irsa.iam_role_arn
}

output "configure_kubectl_command" {
  description = "Run this command to configure kubectl after apply"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.region}"
}
