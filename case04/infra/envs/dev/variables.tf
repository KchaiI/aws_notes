variable "region" {
  description = "AWSリージョン"
  type        = string
  default     = "ap-northeast-1"
}

variable "project" {
  description = "プロジェクト名（リソース名のプレフィックスに使う）"
  type        = string
  default     = "task-api"
}

variable "environment" {
  description = "環境名（dev/stg/prod）"
  type        = string
  default     = "dev"
}