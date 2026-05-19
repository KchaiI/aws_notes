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
  description = "ECSタスクを配置するサブネット(private)"
}

variable "alb_security_group_id" {
  type        = string
  description = "ALB のセキュリティグループ ID(これからの接続を許可)"
}

variable "alb_target_group_arn" {
  type        = string
  description = "ALBのターゲットグループARN(ECSサービスがここに登録)"
}

variable "container_image" {
  type        = string
  description = "ECRイメージ URI(タグ含む)"
}

variable "container_port" {
  type        = number
  default     = 3000
}

variable "cpu" {
  type        = number
  description = "タスク全体のCPUユニット(256=0.25vCPU)"
  default     = 256
}

variable "memory" {
  type        = number
  description = "タスク全体のメモリ(MB)"
  default     = 512
}

variable "desired_count" {
  type        = number
  description = "起動するタスク数"
  default     = 1
}

variable "db_secret_arn" {
  type        = string
  description = "DB認証情報のSecrets Manager ARN (API用のみ必要)"
  default     = null
}

variable "db_endpoint" {
  type        = string
  description = "RDSのエンドポイント (API用のみ必要)"
  default     = null
}

variable "db_port" {
  type        = number
  default     = 5432
}

variable "db_name" {
  type        = string
  description = "DB名 (API用のみ必要)"
  default     = null
}

variable "cluster_arn" {
  type        = string
  description = "既存クラスターARN。nullの場合は新規作成"
  default     = null
}

variable "name_suffix" {
  type        = string
  description = "リソース名サフィックス（同一クラスター内で複数サービスを区別）"
  default     = ""
}

variable "log_retention_days" {
  type    = number
  default = 7
}