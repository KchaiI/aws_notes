output "distribution_id" {
  description = "CloudFront ディストリビューションID"
  value       = aws_cloudfront_distribution.this.id
}

output "domain_name" {
  description = "CloudFront のドメイン名(dxxxxx.cloudfront.net)"
  value       = aws_cloudfront_distribution.this.domain_name
}

output "hosted_zone_id" {
  description = "CloudFront のホストゾーンID(Route 53のAレコード設定に使う)"
  value       = aws_cloudfront_distribution.this.hosted_zone_id
}