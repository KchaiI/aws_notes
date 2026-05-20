locals {
  name_prefix = "${var.project}-${var.environment}"
}

# ──────────────────────────────────────
# CloudFront ディストリビューション
# ──────────────────────────────────────
resource "aws_cloudfront_distribution" "this" {
  enabled         = true
  is_ipv6_enabled = true
  comment         = "${local.name_prefix} distribution"
  web_acl_id      = var.web_acl_id

  # 価格クラス: 最安(北米・欧州のみのエッジ)
  # アジア圏も使うなら PriceClass_200、全球なら PriceClass_All
  price_class = "PriceClass_200"

  # ──────────────────────────────────────
  # オリジン: ALB
  # ──────────────────────────────────────
  origin {
    domain_name = var.alb_dns_name
    origin_id   = var.alb_origin_id

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"      # CloudFront → ALB は HTTP
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # ──────────────────────────────────────
  # デフォルトキャッシュ動作(全パス共通)
  # ──────────────────────────────────────
  default_cache_behavior {
    target_origin_id       = var.alb_origin_id
    viewer_protocol_policy = "redirect-to-https"   # HTTP → HTTPS にリダイレクト

    allowed_methods = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods  = ["GET", "HEAD"]

    # API はキャッシュしないのが基本
    # AWS マネージドポリシー: CachingDisabled
    cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"

    # 全ヘッダー・クエリ・Cookie を転送
    # AWS マネージドポリシー: AllViewer
    origin_request_policy_id = "216adef6-5c7f-47e4-b989-5492eafa07d3"

    compress = true
  }

  # ──────────────────────────────────────
  # 地域制限なし
  # ──────────────────────────────────────
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # ──────────────────────────────────────
  # SSL 証明書: CloudFront デフォルトを使用
  # (独自ドメインなしで dxxxx.cloudfront.net で動かす)
  # ──────────────────────────────────────
  viewer_certificate {
    cloudfront_default_certificate = true
    minimum_protocol_version       = "TLSv1"   # デフォルト証明書を使う場合は変えられない
  }

  tags = {
    Name = "${local.name_prefix}-cloudfront"
  }
}