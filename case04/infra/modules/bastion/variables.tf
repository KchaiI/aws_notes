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

variable "public_subnet_id" {
  type        = string
  description = "踏み台を配置するパブリックサブネットID（1つだけ指定）"
}

variable "instance_type" {
  type        = string
  description = "踏み台のインスタンスタイプ"
  default     = "t4g.nano"
}