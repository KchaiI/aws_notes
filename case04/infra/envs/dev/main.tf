module "network" {
  source = "../../modules/network"

  project     = var.project
  environment = var.environment
  azs         = ["ap-northeast-1c", "ap-northeast-1d"]
}

module "ecr" {
  source = "../../modules/ecr"

  project     = var.project
  environment = var.environment
}

module "bastion" {
  source = "../../modules/bastion"

  project          = var.project
  environment      = var.environment
  vpc_id           = module.network.vpc_id
  public_subnet_id = module.network.public_subnet_ids[0]
}

module "alb" {
  source = "../../modules/alb"

  project           = var.project
  environment       = var.environment
  vpc_id            = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids
}

module "ecs" {
  source = "../../modules/ecs"

  project              = var.project
  environment          = var.environment
  vpc_id               = module.network.vpc_id
  app_subnet_ids       = module.network.app_subnet_ids
  alb_security_group_id = module.alb.security_group_id
  alb_target_group_arn = module.alb.target_group_arn

  container_image = "${module.ecr.repository_url}:latest"

  db_secret_arn = module.rds.secret_arn
  db_endpoint   = module.rds.address
  db_name       = "taskapi"
}

module "rds" {
  source = "../../modules/rds"

  project       = var.project
  environment   = var.environment
  vpc_id        = module.network.vpc_id
  db_subnet_ids = module.network.db_subnet_ids

  # 踏み台SG + ECSタスクSG からのアクセスを許可
  allowed_security_group_ids = [
    module.bastion.security_group_id,
    module.ecs.security_group_id,
  ]

  db_engine_version = "16.10"
}

module "cloudfront" {
  source = "../../modules/cloudfront"

  project      = var.project
  environment  = var.environment
  alb_dns_name = module.alb.alb_dns_name
}