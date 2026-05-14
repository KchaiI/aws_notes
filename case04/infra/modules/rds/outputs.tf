output "endpoint" {
  description = "RDSエンドポイント（host:port形式）"
  value       = aws_db_instance.this.endpoint
}

output "address" {
  description = "RDSエンドポイント（hostのみ）"
  value       = aws_db_instance.this.address
}

output "port" {
  description = "RDSポート番号"
  value       = aws_db_instance.this.port
}

output "db_name" {
  description = "データベース名"
  value       = aws_db_instance.this.db_name
}

output "security_group_id" {
  description = "RDSのセキュリティグループID"
  value       = aws_security_group.rds.id
}

output "secret_arn" {
  description = "Secrets ManagerのシークレットARN"
  value       = aws_secretsmanager_secret.db.arn
}

output "secret_name" {
  description = "Secrets Managerのシークレット名"
  value       = aws_secretsmanager_secret.db.name
}