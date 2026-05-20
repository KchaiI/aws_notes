output "web_acl_arn" {
  description = "WAF Web ACL の ARN（CloudFront に渡す）"
  value       = aws_wafv2_web_acl.this.arn
}
