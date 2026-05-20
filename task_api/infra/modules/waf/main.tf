locals {
  name_prefix = "${var.project}-${var.environment}"
}

# ──────────────────────────────────────
# WAF Web ACL（CloudFront 用: us-east-1 に作成する必要あり）
# ──────────────────────────────────────
resource "aws_wafv2_web_acl" "this" {
  name  = "${local.name_prefix}-waf"
  scope = "CLOUDFRONT"

  default_action {
    allow {}
  }

  # メンテナンス中は全リクエストを 503 でブロック
  dynamic "rule" {
    for_each = var.maintenance_mode ? [1] : []
    content {
      name     = "maintenance-block-all"
      priority = 1

      action {
        block {
          custom_response {
            response_code            = 503
            custom_response_body_key = "maintenance"
          }
        }
      }

      statement {
        byte_match_statement {
          search_string = "/"
          field_to_match {
            uri_path {}
          }
          text_transformation {
            priority = 0
            type     = "NONE"
          }
          positional_constraint = "STARTS_WITH"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = false
        metric_name                = "${local.name_prefix}-maintenance-block"
        sampled_requests_enabled   = false
      }
    }
  }

  custom_response_body {
    key          = "maintenance"
    content      = "{\"message\": \"メンテナンス中です。しばらくお待ちください。\"}"
    content_type = "APPLICATION_JSON"
  }

  visibility_config {
    cloudwatch_metrics_enabled = false
    metric_name                = "${local.name_prefix}-waf"
    sampled_requests_enabled   = false
  }

  tags = {
    Name = "${local.name_prefix}-waf"
  }
}
