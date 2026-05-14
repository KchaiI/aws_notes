variable "project" {
  type        = string
  description = "プロジェクト名"
}

variable "environment" {
  type        = string
  description = "環境名"
}

variable "alb_dns_name" {
  type        = string
  description = "オリジンとなるALBのDNS名"
}

variable "alb_origin_id" {
  type        = string
  description = "CloudFront内部で使うオリジン識別子"
  default     = "alb-origin"
}