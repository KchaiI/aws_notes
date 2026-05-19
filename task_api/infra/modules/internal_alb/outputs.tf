output "dns_name" {
  description = "Internal ALB の DNS 名（フロントエンドの INTERNAL_API_URL に設定）"
  value       = aws_lb.internal.dns_name
}

output "security_group_id" {
  description = "Internal ALB の SG ID（API ECS SG の追加許可ルールに使用）"
  value       = aws_security_group.internal_alb.id
}

output "target_group_arn" {
  description = "API 用ターゲットグループ ARN（API ECS サービスの load_balancer に登録）"
  value       = aws_lb_target_group.api.arn
}
