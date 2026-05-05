variable "region" {
  description = "AWS region"
  default     = "ap-south-1"
}

variable "cluster_name" {
  description = "EKS cluster name"
  default     = "petclinic-cluster"
}

variable "cluster_version" {
  description = "Kubernetes version"
  default     = "1.32"
}
