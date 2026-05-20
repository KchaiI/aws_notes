# STEP06: WAF メンテナンスモード

## 概要
AWS WAFv2 を CloudFront に紐付け、Terraform 変数 `maintenance_mode=true` を渡すだけで全リクエストを 503 でブロックできるメンテナンスモードを実装する。

## なぜ WAF を us-east-1 に作るのか
CloudFront に紐付ける WAF Web ACL は **必ず us-east-1 (グローバル)** に作成しなければならない。  
ALB/API Gateway 用の WAF (REGIONAL スコープ) とは別物。

## 実装内容

### 1. modules/waf/ (新規モジュール)
**main.tf**
```hcl
resource "aws_wafv2_web_acl" "this" {
  name  = "${local.name_prefix}-waf"
  scope = "CLOUDFRONT"   # us-east-1 必須

  default_action { allow {} }  # 通常時は全許可

  # メンテナンス中のみルールを追加
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
          search_string         = "/"
          positional_constraint = "STARTS_WITH"
          field_to_match { uri_path {} }
          text_transformation { priority = 0; type = "NONE" }
        }
      }
      ...
    }
  }

  custom_response_body {
    key          = "maintenance"
    content      = "{\"message\": \"メンテナンス中です。しばらくお待ちください。\"}"
    content_type = "APPLICATION_JSON"
  }
}
```

**ポイント**: `dynamic "rule"` + `for_each = var.maintenance_mode ? [1] : []` で、フラグが true の時だけルールを生成し、false なら WAF は全リクエストを通す。

### 2. modules/cloudfront/variables.tf に web_acl_id 追加
```hcl
variable "web_acl_id" {
  type    = string
  default = null
}
```

### 3. modules/cloudfront/main.tf に web_acl_id 追加
```hcl
resource "aws_cloudfront_distribution" "this" {
  ...
  web_acl_id = var.web_acl_id
}
```

### 4. envs/dev/providers.tf に us-east-1 プロバイダー追加
```hcl
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
  ...
}
```

### 5. envs/dev/variables.tf に maintenance_mode 追加
```hcl
variable "maintenance_mode" {
  type    = bool
  default = false
}
```

### 6. envs/dev/main.tf に WAF モジュール追加
```hcl
module "waf" {
  source   = "../../modules/waf"
  providers = { aws = aws.us_east_1 }   # us-east-1 で作成
  
  project          = var.project
  environment      = var.environment
  maintenance_mode = var.maintenance_mode
}

module "cloudfront" {
  ...
  web_acl_id = module.waf.web_acl_arn  # WAF を CloudFront に紐付け
}
```

## 使い方

### メンテナンスモード ON
```bash
cd task_api/infra/envs/dev
terraform apply -var="maintenance_mode=true"
# CloudFront の伝播を待つ（数分）
aws cloudfront wait distribution-deployed --id <DISTRIBUTION_ID>
```

アクセスすると全パスで 503:
```json
{"message": "メンテナンス中です。しばらくお待ちください。"}
```

### メンテナンスモード OFF（通常に戻す）
```bash
terraform apply -var="maintenance_mode=false"
aws cloudfront wait distribution-deployed --id <DISTRIBUTION_ID>
```

## 注意点
- CloudFront への変更は **デプロイに数分かかる**（WAF が設定されてもすぐには反映されない）
- `aws cloudfront wait distribution-deployed` でデプロイ完了を待てる
- WAF は CloudFront のキャッシュより先に評価されるため、キャッシュがあっても確実にブロックできる

## アーキテクチャ
```
ユーザー
  ↓ HTTPS
CloudFront (WAF 評価 → maintenance_mode=true なら 503 返却)
  ↓ HTTP (通常時のみ)
ALB
  ├── /api/* → ECS API
  └── /*     → ECS Frontend
```
