locals {
  name_prefix = "${var.project}-${var.environment}"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ──────────────────────────────────────
# S3 バケット（プライベート・暗号化）
# ──────────────────────────────────────
resource "aws_s3_bucket" "images" {
  bucket        = "${local.name_prefix}-images"
  force_destroy = true

  tags = {
    Name = "${local.name_prefix}-images"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "images" {
  bucket = aws_s3_bucket.images.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "images" {
  bucket = aws_s3_bucket.images.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ──────────────────────────────────────
# CORS（ブラウザからの Presigned PUT を許可）
# ──────────────────────────────────────
resource "aws_s3_bucket_cors_configuration" "images" {
  bucket = aws_s3_bucket.images.id

  cors_rule {
    allowed_origins = ["*"]
    allowed_methods = ["PUT"]
    allowed_headers = ["*"]
    max_age_seconds = 3000
  }
}

# ──────────────────────────────────────
# CloudFront OAC（S3 へのアクセス制御）
# ──────────────────────────────────────
resource "aws_cloudfront_origin_access_control" "images" {
  name                              = "${local.name_prefix}-images-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# ──────────────────────────────────────
# Signed URL 用キーペア
# ──────────────────────────────────────
resource "tls_private_key" "cf_signing" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_cloudfront_public_key" "this" {
  name        = "${local.name_prefix}-cf-signing-key"
  encoded_key = tls_private_key.cf_signing.public_key_pem
}

resource "aws_cloudfront_key_group" "this" {
  name    = "${local.name_prefix}-cf-key-group"
  items   = [aws_cloudfront_public_key.this.id]
  comment = "Key group for signed URL"
}

# ──────────────────────────────────────
# 秘密鍵を Secrets Manager に保存
# ──────────────────────────────────────
resource "aws_secretsmanager_secret" "cf_private_key" {
  name                    = "${local.name_prefix}-cf-private-key"
  recovery_window_in_days = 0

  tags = {
    Name = "${local.name_prefix}-cf-private-key"
  }
}

resource "aws_secretsmanager_secret_version" "cf_private_key" {
  secret_id     = aws_secretsmanager_secret.cf_private_key.id
  secret_string = tls_private_key.cf_signing.private_key_pem
}

# ──────────────────────────────────────
# CloudFront ディストリビューション（画像配信）
# ──────────────────────────────────────
resource "aws_cloudfront_distribution" "images" {
  enabled         = true
  is_ipv6_enabled = true
  comment         = "${local.name_prefix} images distribution"
  price_class     = "PriceClass_200"

  origin {
    domain_name              = aws_s3_bucket.images.bucket_regional_domain_name
    origin_id                = "s3-images"
    origin_access_control_id = aws_cloudfront_origin_access_control.images.id
  }

  default_cache_behavior {
    target_origin_id       = "s3-images"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]

    # Signed URL を必須にする
    trusted_key_groups = [aws_cloudfront_key_group.this.id]

    # AWS マネージドポリシー: CachingOptimized
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"

    compress = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
    minimum_protocol_version       = "TLSv1"
  }

  tags = {
    Name = "${local.name_prefix}-images-cloudfront"
  }

  depends_on = [aws_s3_bucket_public_access_block.images]
}

# ──────────────────────────────────────
# S3 バケットポリシー（OAC からのみ許可）
# ──────────────────────────────────────
resource "aws_s3_bucket_policy" "images" {
  bucket = aws_s3_bucket.images.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontOAC"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.images.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.images.arn
          }
        }
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.images]
}
