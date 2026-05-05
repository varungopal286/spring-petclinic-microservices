module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "petclinic-vpc"
  cidr = "10.0.0.0/16"

  azs            = ["${var.region}a", "${var.region}b"]
  public_subnets = ["10.0.1.0/24", "10.0.2.0/24"]

  enable_dns_hostnames    = true
  enable_dns_support      = true
  map_public_ip_on_launch = true

  # Required tags so EKS and ALB controller can find these subnets
  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  tags = {
    Project     = "petclinic"
    Environment = "capstone"
  }
}
