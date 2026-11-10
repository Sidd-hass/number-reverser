data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  project_name = "number-reverser"

  common_tags = {
    Project     = local.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

module "networking" {
  source = "../../modules/networking"

  project_name       = local.project_name
  vpc_cidr           = var.vpc_cidr
  public_subnet_cidr = var.public_subnet_cidr
  availability_zone  = data.aws_availability_zones.available.names[0]
  tags               = local.common_tags
}

module "security" {
  source = "../../modules/security"

  project_name = local.project_name
  vpc_id       = module.networking.vpc_id
  tags         = local.common_tags
}

module "iam" {
  source = "../../modules/iam"

  project_name = local.project_name
  tags         = local.common_tags
}

module "compute" {
  source = "../../modules/compute"

  project_name          = local.project_name
  instance_type         = var.instance_type
  root_volume_size      = var.root_volume_size
  subnet_id             = module.networking.public_subnet_id
  security_group_id     = module.security.security_group_id
  instance_profile_name = module.iam.instance_profile_name
  tags                  = local.common_tags
}
