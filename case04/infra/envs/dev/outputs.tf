output "vpc_id" {
  value = module.network.vpc_id
}

output "public_subnet_ids" {
  value = module.network.public_subnet_ids
}

output "app_subnet_ids" {
  value = module.network.app_subnet_ids
}

output "db_subnet_ids" {
  value = module.network.db_subnet_ids
}

output "ecr_repository_url" {
  value = module.ecr.repository_url
}

output "bastion_instance_id" {
  value = module.bastion.instance_id
}

output "rds_endpoint" {
  value = module.rds.address
}

output "rds_secret_arn" {
  value = module.rds.secret_arn
}

output "alb_dns_name" {
  description = "ALBのDNS名(APIエンドポイント)"
  value       = module.alb.alb_dns_name
}

output "ecs_cluster_name" {
  value = module.ecs.cluster_name
}

output "ecs_service_name" {
  value = module.ecs.service_name
}

output "ecs_log_group_name" {
  value = module.ecs.log_group_name
}