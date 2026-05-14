variable "aws_region" {
  description = "AWSリージョン"
  type        = string
  default     = "ap-northeast-1"
}

variable "project_name" {
  description = "リソース名のプレフィックス"
  type        = string
  default     = "kadai2-slack"
}

variable "slack_webhook_url" {
  description = "Slack Incoming Webhook URL"
  type        = string
  sensitive   = true
}

variable "schedule_expression" {
  description = "EventBridgeのスケジュール式 (cron または rate)"
  type        = string
  # 例: "rate(5 minutes)" / "cron(0 9 * * ? *)" (毎日UTC9時 = JST18時)
  default = "rate(5 minutes)"
}
