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

module "rds" {
  source = "../../modules/rds"

  project       = var.project
  environment   = var.environment
  vpc_id        = module.network.vpc_id
  db_subnet_ids = module.network.db_subnet_ids

  # 踏み台SGからのアクセスを許可
  allowed_security_group_ids = [module.bastion.security_group_id]

  db_engine_version = "16.10"
}