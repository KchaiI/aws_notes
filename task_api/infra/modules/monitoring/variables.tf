variable "project" {
  type        = string
  description = "プロジェクト名"
}

variable "environment" {
  type        = string
  description = "環境名"
}

variable "cluster_name" {
  type        = string
  description = "監視対象の ECS クラスター名"
}

variable "service_name" {
  type        = string
  description = "監視対象の ECS サービス名"
}

variable "log_group_name" {
  type        = string
  description = "CloudWatch Logs グループ名（Insights クエリの対象）"
}

variable "slack_webhook_url" {
  type        = string
  description = "Slack Incoming Webhook URL"
  sensitive   = true
}

variable "cpu_alarm_threshold" {
  type        = number
  description = "CPU 使用率アラームの閾値（%）"
  default     = 1
}
