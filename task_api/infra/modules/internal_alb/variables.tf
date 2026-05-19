variable "project" {
  type        = string
  description = "プロジェクト名"
}

variable "environment" {
  type        = string
  description = "環境名"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "app_subnet_ids" {
  type        = list(string)
  description = "Internal ALB を配置するプライベートサブネット"
}

variable "allowed_security_group_ids" {
  type        = list(string)
  description = "Internal ALB へのアクセスを許可する SG ID リスト（フロントエンド ECS SG を渡す）"
}

variable "api_port" {
  type        = number
  description = "API コンテナのポート番号"
  default     = 3000
}
