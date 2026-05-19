output "alb_arn" {
  value = aws_lb.this.arn
}

output "alb_dns_name" {
  description = "ALBのDNS名(これがエンドポイント)"
  value       = aws_lb.this.dns_name
}

output "alb_zone_id" {
  value = aws_lb.this.zone_id
}

output "target_group_arn" {
  description = "ターゲットグループARN(ECSサービスが登録対象として使う)"
  value       = aws_lb_target_group.this.arn
}

output "security_group_id" {
  description = "ALBのSG ID(ECS SGから許可するため)"
  value       = aws_security_group.alb.id
}

output "frontend_target_group_arn" {
  description = "フロントエンド用ターゲットグループARN"
  value       = aws_lb_target_group.frontend.arn
}