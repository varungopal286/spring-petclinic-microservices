# IAM Role for AWS Load Balancer Controller using IRSA
# IRSA = IAM Roles for Service Accounts
# This lets the ALB controller pod call AWS APIs securely
# without any hardcoded credentials
module "alb_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.37"

  role_name                              = "aws-load-balancer-controller"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    eks = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = {
    Project = "petclinic"
  }
}
