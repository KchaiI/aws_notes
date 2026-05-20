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

  project               = var.project
  environment           = var.environment
  vpc_id                = module.network.vpc_id
  app_subnet_ids        = module.network.app_subnet_ids
  alb_security_group_id = module.alb.security_group_id
  alb_target_group_arn  = module.alb.target_group_arn

  container_image = "${module.ecr.repository_url}:latest"

  create_cluster                = true
  enable_db                     = true
  db_secret_arn                 = module.rds.secret_arn
  db_endpoint                   = module.rds.address
  db_name                       = "taskapi"
  additional_ingress_sg_ids     = [module.internal_alb.security_group_id]
  register_to_internal_alb      = true
  internal_alb_target_group_arn = module.internal_alb.target_group_arn
  enable_s3_access              = true
  s3_bucket_arn                 = module.s3_images.bucket_arn
  cf_private_key_secret_arn     = module.s3_images.private_key_secret_arn
  extra_environment = [
    { name = "S3_BUCKET_NAME",             value = module.s3_images.bucket_name },
    { name = "CF_DOMAIN",                  value = module.s3_images.cloudfront_domain },
    { name = "CF_KEY_PAIR_ID",             value = module.s3_images.cf_public_key_id },
    { name = "CF_PRIVATE_KEY_SECRET_ARN",  value = module.s3_images.private_key_secret_arn },
  ]
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

module "s3_images" {
  source = "../../modules/s3_images"

  project     = var.project
  environment = var.environment
}

module "internal_alb" {
  source = "../../modules/internal_alb"

  project                    = var.project
  environment                = var.environment
  vpc_id                     = module.network.vpc_id
  app_subnet_ids             = module.network.app_subnet_ids
  allowed_security_group_ids = [module.ecs_frontend.security_group_id]
}

module "ecr_frontend" {
  source = "../../modules/ecr"

  project         = var.project
  environment     = var.environment
  repository_name = "frontend"
}

module "ecs_frontend" {
  source = "../../modules/ecs"

  project               = var.project
  environment           = var.environment
  name_suffix           = "frontend"
  create_cluster        = false
  cluster_arn           = module.ecs.cluster_arn
  enable_db             = false
  extra_environment = [
    { name = "INTERNAL_API_URL", value = "http://${module.internal_alb.dns_name}" }
  ]
  vpc_id                = module.network.vpc_id
  app_subnet_ids        = module.network.app_subnet_ids
  alb_security_group_id = module.alb.security_group_id
  alb_target_group_arn  = module.alb.frontend_target_group_arn
  container_image       = "${module.ecr_frontend.repository_url}:latest"
  container_port        = 3000
  desired_count         = 0
}

module "github_oidc" {
  source = "../../modules/github_oidc"

  project     = var.project
  environment = var.environment

  github_owner = "KchaiI"
  github_repo  = "aws_notes"

  allowed_branches = ["main"]

  ecr_repository_arn       = module.ecr.repository_arn
  ecs_cluster_arn          = module.ecs.cluster_arn
  ecs_service_arn          = module.ecs.service_arn
  task_execution_role_arn  = module.ecs.task_execution_role_arn
  task_role_arn            = module.ecs.task_role_arn
}