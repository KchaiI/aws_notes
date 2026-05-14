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
  description = "踏み台EC2インスタンスID"
  value       = module.bastion.instance_id
}

output "rds_endpoint" {
  description = "RDSのエンドポイント"
  value       = module.rds.address
}

output "rds_secret_arn" {
  description = "DB認証情報のSecrets Manager ARN"
  value       = module.rds.secret_arn
}