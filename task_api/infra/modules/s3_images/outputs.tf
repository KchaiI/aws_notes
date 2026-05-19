output "bucket_name" {
  description = "画像バケット名（API が presigned URL を発行する際に使用）"
  value       = aws_s3_bucket.images.bucket
}

output "bucket_arn" {
  description = "画像バケット ARN（ECS タスクロールの権限設定に使用）"
  value       = aws_s3_bucket.images.arn
}

output "cloudfront_domain" {
  description = "画像配信 CloudFront ドメイン（API が Signed URL を発行する際に使用）"
  value       = aws_cloudfront_distribution.images.domain_name
}

output "cloudfront_distribution_arn" {
  description = "CloudFront ディストリビューション ARN"
  value       = aws_cloudfront_distribution.images.arn
}

output "cf_public_key_id" {
  description = "CloudFront 公開鍵 ID（Signed URL 生成時の key pair ID として使用）"
  value       = aws_cloudfront_public_key.this.id
}

output "private_key_secret_arn" {
  description = "CF 秘密鍵の Secrets Manager ARN（API が Signed URL を生成する際に取得）"
  value       = aws_secretsmanager_secret.cf_private_key.arn
}
