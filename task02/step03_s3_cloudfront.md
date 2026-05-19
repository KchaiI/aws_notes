# STEP03: S3（暗号化）+ CloudFront（画像配信）

## 概要

タスクに添付する画像をプライベート S3 に暗号化して保存し、
CloudFront Signed URL 経由でのみ配信する基盤を構築する。

---

## アーキテクチャ

```
【画像アップロード】
Frontend → POST /api/tasks/upload-url → API
                                          ↓
                                   S3 Presigned URL 発行
                                          ↓
Frontend → PUT presigned-url → S3（プライベート・暗号化）

【画像表示】
Frontend → GET /api/tasks/:id → API
                                  ↓
                           CloudFront Signed URL 発行
                           （有効期限付き）
                                  ↓
Frontend → GET signed-url → CloudFront → S3（OAC 認証）
```

### ポイント
- S3 は完全プライベート（パブリックアクセス全ブロック）
- S3 への直接アクセス不可。CloudFront OAC 経由のみ許可
- 画像 URL は毎回 Signed URL を発行（有効期限付き）→ 直リンク共有不可

---

## 変更したファイル一覧

### 1. `infra/modules/s3_images/` （新規モジュール）

**main.tf に含まれるリソース**

| リソース | 内容 |
|---|---|
| `aws_s3_bucket` | プライベートバケット |
| `aws_s3_bucket_server_side_encryption_configuration` | SSE-S3 暗号化（AES-256）|
| `aws_s3_bucket_public_access_block` | パブリックアクセス全ブロック |
| `aws_cloudfront_origin_access_control` | OAC（CloudFront → S3 認証）|
| `aws_cloudfront_distribution` | 画像配信用 CloudFront |
| `aws_s3_bucket_policy` | OAC からの GetObject のみ許可 |
| `tls_private_key` | RSA 2048 bit キーペア生成（Signed URL 署名用）|
| `aws_cloudfront_public_key` | CloudFront に公開鍵を登録 |
| `aws_cloudfront_key_group` | 公開鍵をグループ化 |
| `aws_secretsmanager_secret` | 秘密鍵を Secrets Manager に保存 |

**outputs.tf の主な出力**

| 出力 | 用途 |
|---|---|
| `bucket_name` | API が presigned URL を発行する際のバケット名 |
| `bucket_arn` | ECS タスクロールの S3 権限設定 |
| `cloudfront_domain` | API が Signed URL を発行する際のドメイン |
| `cf_public_key_id` | Signed URL 生成時の key pair ID |
| `private_key_secret_arn` | API が Secrets Manager から秘密鍵を取得するための ARN |

---

### 2. `infra/modules/ecs/variables.tf`

| 追加変数 | デフォルト | 説明 |
|---|---|---|
| `enable_s3_access` | `false` | S3 + Secrets Manager 権限を付与するフラグ |
| `s3_bucket_arn` | `null` | 対象 S3 バケットの ARN |
| `cf_private_key_secret_arn` | `null` | CF 秘密鍵の Secrets Manager ARN |

---

### 3. `infra/modules/ecs/main.tf`

API の **タスクロール**（アプリが実行時に使う IAM ロール）に以下を追加：

```
S3 権限:
  s3:PutObject   → presigned URL 発行（クライアントが直接アップロード）
  s3:GetObject   → 必要に応じてオブジェクト確認
  s3:DeleteObject → 画像削除

Secrets Manager 権限:
  secretsmanager:GetSecretValue → CF 秘密鍵の取得（Signed URL 生成時）
```

---

### 4. `infra/envs/dev/versions.tf`

`tls` プロバイダーを追加（RSA キーペア生成に必要）：
```hcl
tls = {
  source  = "hashicorp/tls"
  version = "~> 4.0"
}
```

### 5. `infra/envs/dev/main.tf`

```hcl
module "s3_images" {
  source = "../../modules/s3_images"
  ...
}

module "ecs" {
  ...
  enable_s3_access          = true
  s3_bucket_arn             = module.s3_images.bucket_arn
  cf_private_key_secret_arn = module.s3_images.private_key_secret_arn
}
```

---

## 新規作成されるリソース

| リソース名 | 種別 |
|---|---|
| `task-api-dev-images` | S3 バケット（プライベート・AES-256 暗号化）|
| `task-api-dev-images-oac` | CloudFront OAC |
| CloudFront ディストリビューション（S3 用）| 画像配信 CDN |
| `task-api-dev-cf-signing-key` | CloudFront 公開鍵 |
| `task-api-dev-cf-key-group` | CloudFront キーグループ |
| `task-api-dev-cf-private-key` | Secrets Manager シークレット（秘密鍵）|

---

## 次のステップ（STEP04）

`task` ドメインに `picture_url` 属性を追加（Prisma スキーマ変更 + マイグレーション）

---

## terraform 適用手順

```bash
cd task_api/infra/envs/dev
terraform init   # tls プロバイダーのインストールが必要
terraform plan
terraform apply
```
