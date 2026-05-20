================================================================
STEP 03: Terraform CSV用 S3 バケットの作成
================================================================

## 作成ファイル
- task_api/infra/modules/s3_csv/main.tf
- task_api/infra/modules/s3_csv/variables.tf
- task_api/infra/modules/s3_csv/outputs.tf
- task_api/infra/envs/dev/main.tf  （モジュール呼び出し追加）

---

## modules/s3_csv/main.tf

```hcl
resource "aws_s3_bucket" "this" {
  bucket = var.bucket_name

  tags = {
    Name = var.bucket_name
  }
}

# パブリックアクセスを完全禁止
resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 暗号化（AES256）
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ライフサイクル: 7日後に自動削除（古いCSVを溜めない）
resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    id     = "expire-csv"
    status = "Enabled"

    expiration {
      days = 7
    }
  }
}
```

---

## modules/s3_csv/variables.tf

```hcl
variable "bucket_name" {
  type = string
}
```

---

## modules/s3_csv/outputs.tf

```hcl
output "bucket_name" {
  value = aws_s3_bucket.this.id
}

output "bucket_arn" {
  value = aws_s3_bucket.this.arn
}
```

---

## envs/dev/main.tf への追記

```hcl
module "s3_csv" {
  source      = "../../modules/s3_csv"
  bucket_name = "task-api-csv-exports-dev"
}
```

---

## 画像用S3との違い

| 項目           | 画像用S3 (s3_images)         | CSV用S3 (s3_csv)              |
|----------------|------------------------------|-------------------------------|
| 配信方法        | CloudFront Signed URL        | S3 Presigned URL              |
| 有効期限        | 1時間                        | 10分（短め）                  |
| ライフサイクル  | なし                         | 7日後に自動削除               |
| 用途            | 画像の永続保管               | 一時的なCSVファイル           |

---

## ポイント

- 画像用S3とは別バケット（用途が異なり、ライフサイクルも違う）
- CloudFrontは不要: CSVは一時的なファイルなのでPresigned URLで直接配信
- ライフサイクルルールで古いCSVを自動削除（ストレージコスト削減）
