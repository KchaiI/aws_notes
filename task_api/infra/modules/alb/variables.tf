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

variable "public_subnet_ids" {
  type        = list(string)
  description = "ALBを配置するパブリックサブネット"
}

variable "target_port" {
  type        = number
  description = "ターゲット(ECS)のポート番号"
  default     = 3000
}

variable "health_check_path" {
  type        = string
  description = "ヘルスチェックのパス"
  default     = "/health"
}

variable "frontend_port" {
  type        = number
  description = "フロントエンドコンテナのポート番号"
  default     = 3000
}

variable "frontend_health_check_path" {
  type        = string
  description = "フロントエンドのヘルスチェックパス"
  default     = "/"
}