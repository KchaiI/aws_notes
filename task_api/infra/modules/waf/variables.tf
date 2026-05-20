variable "project" {
  type        = string
  description = "プロジェクト名"
}

variable "environment" {
  type        = string
  description = "環境名"
}

variable "maintenance_mode" {
  type        = bool
  description = "true にすると全リクエストを 503 でブロックする"
  default     = false
}
