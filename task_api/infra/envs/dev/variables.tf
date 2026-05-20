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

variable "maintenance_mode" {
  description = "true にすると WAF が全リクエストを 503 でブロックする"
  type        = bool
  default     = false
}