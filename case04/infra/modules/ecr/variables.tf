variable "project" {
  type        = string
  description = "プロジェクト名"
}

variable "environment" {
  type        = string
  description = "環境名"
}

variable "repository_name" {
  type        = string
  description = "ECRリポジトリ名（プロジェクト+環境のプレフィックスは付かない、シンプルな名前）"
  default     = "task-api"
}

variable "image_retention_count" {
  type        = number
  description = "保持する最新イメージ数。これより古いイメージは自動削除"
  default     = 10
}