locals {
  name_prefix = "${var.project}-${var.environment}"
}

# ──────────────────────────────────────
# ECR リポジトリ
# ──────────────────────────────────────
resource "aws_ecr_repository" "this" {
  name                 = "${local.name_prefix}-${var.repository_name}"
  image_tag_mutability = "MUTABLE"  # 同じタグの上書きを許可（latestタグなどで便利）
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true  # push時に脆弱性スキャンを自動実行
  }

  tags = {
    Name = "${local.name_prefix}-${var.repository_name}"
  }
}

# ──────────────────────────────────────
# ライフサイクルポリシー（古いイメージの自動削除）
# ──────────────────────────────────────
resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "最新${var.image_retention_count}件以外のイメージを削除"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.image_retention_count
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}