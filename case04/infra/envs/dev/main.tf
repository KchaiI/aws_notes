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