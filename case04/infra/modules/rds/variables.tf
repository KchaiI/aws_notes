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
  description = "VPC ID（networkモジュールから受け取る）"
}

variable "db_subnet_ids" {
  type        = list(string)
  description = "RDSを配置するサブネットID（dbサブネット）"
}

variable "allowed_security_group_ids" {
  type        = list(string)
  description = "RDSへの接続を許可するセキュリティグループのIDリスト（踏み台、後にECS）"
  default     = []
}

variable "db_name" {
  type        = string
  description = "初期作成するデータベース名"
  default     = "taskapi"
}

variable "db_username" {
  type        = string
  description = "DBマスターユーザー名"
  default     = "taskapi_admin"
}

variable "db_instance_class" {
  type        = string
  description = "RDSインスタンスクラス"
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  type        = number
  description = "初期割り当てストレージ（GB）"
  default     = 20
}

variable "db_engine_version" {
  type        = string
  description = "PostgreSQLのバージョン"
  default     = "16.10"
}