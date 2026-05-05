terraform {
  backend "s3" {
    bucket         = "petclinic-tfstate-622215956811"
    key            = "petclinic/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "petclinic-terraform-locks"
    encrypt        = true
  }
}
