# Image names MUST match what Maven buildDocker profile creates:
# springcommunity/spring-petclinic-SERVICE (NOT springcommunity/SERVICE)
locals {
  services = [
    "spring-petclinic-config-server",
    "spring-petclinic-discovery-server",
    "spring-petclinic-customers-service",
    "spring-petclinic-vets-service",
    "spring-petclinic-visits-service",
    "spring-petclinic-api-gateway",
  ]
}

resource "aws_ecr_repository" "petclinic" {
  for_each = toset(local.services)

  name                 = "petclinic/${each.key}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Project = "petclinic"
  }
}
