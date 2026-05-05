module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnets

  # Allow kubectl access from your laptop
  cluster_endpoint_public_access = true

  eks_managed_node_groups = {
    petclinic = {
      instance_types = ["t3.medium"]
      min_size       = 2
      max_size       = 3
      desired_size   = 2

      # Allows nodes to pull images from ECR without any imagePullSecret
      # No 12-hour token expiry issue — works permanently via IAM role
      iam_role_additional_policies = {
        ecr_readonly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
      }
    }
  }

  # Gives your IAM user (petclinic-admin) full admin access to the cluster
  enable_cluster_creator_admin_permissions = true

  tags = {
    Project     = "petclinic"
    Environment = "capstone"
  }
}
