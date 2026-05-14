module "network" {
  source = "../../modules/network"

  project     = var.project
  environment = var.environment
}