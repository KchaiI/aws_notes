output "role_arn" {
  description = "GitHub Actionsが引き受けるIAMロールのARN"
  value       = aws_iam_role.github_actions.arn
}

output "oidc_provider_arn" {
  description = "OIDCプロバイダのARN"
  value       = data.aws_iam_openid_connect_provider.github.arn
}