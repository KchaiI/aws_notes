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
  description = "既存クラスターARN。create_cluster=falseの場合に必須"
  default     = null
}

variable "create_cluster" {
  type        = bool
  description = "trueの場合クラスターを新規作成、falseの場合はcluster_arnを使用"
  default     = true
}

variable "enable_db" {
  type        = bool
  description = "trueの場合にDB環境変数・Secrets Manager権限を付与する"
  default     = false
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

variable "additional_ingress_sg_ids" {
  type        = list(string)
  description = "追加で許可する SG ID リスト（Internal ALB SG など）"
  default     = []
}

variable "extra_environment" {
  type = list(object({
    name  = string
    value = string
  }))
  description = "追加の環境変数（INTERNAL_API_URL など）"
  default     = []
}

variable "register_to_internal_alb" {
  type        = bool
  description = "trueの場合 Internal ALB のターゲットグループに登録する"
  default     = false
}

variable "internal_alb_target_group_arn" {
  type        = string
  description = "Internal ALB のターゲットグループ ARN（register_to_internal_alb=true の場合に必須）"
  default     = null
}

variable "enable_s3_access" {
  type        = bool
  description = "trueの場合 S3 + Secrets Manager（CF秘密鍵）権限をタスクロールに付与する"
  default     = false
}

variable "s3_bucket_arn" {
  type        = string
  description = "アクセスを許可する S3 バケット ARN（enable_s3_access=true の場合に必須）"
  default     = null
}

variable "cf_private_key_secret_arn" {
  type        = string
  description = "CloudFront 秘密鍵の Secrets Manager ARN（enable_s3_access=true の場合に必須）"
  default     = null
}

variable "enable_sqs_send" {
  type        = bool
  description = "trueの場合 SQS SendMessage 権限をタスクロールに付与する"
  default     = false
}

variable "sqs_csv_queue_arn" {
  type        = string
  description = "SendMessage を許可する SQS キュー ARN（enable_sqs_send=true の場合に必須）"
  default     = null
}

variable "s3_csv_bucket_arn" {
  type        = string
  description = "Presigned URL 生成のために GetObject を許可する CSV 用 S3 バケット ARN"
  default     = null
}