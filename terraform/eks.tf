module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnets

  # Allow kubectl access from your laptop
  cluster_endpoint_public_access = true

  # EBS CSI driver installed automatically — required for PVC on EKS 1.23+
  cluster_addons = {
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }

  eks_managed_node_groups = {
    petclinic = {
      instance_types = ["t3.medium"]
      min_size       = 2
      max_size       = 3
      desired_size   = 2

      iam_role_additional_policies = {
        ecr_readonly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
        ebs_csi      = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
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
