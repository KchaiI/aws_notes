variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "app_subnet_ids" {
  type = list(string)
}

variable "cluster_arn" {
  type = string
}

variable "container_image" {
  type = string
}

variable "cpu" {
  type    = number
  default = 256
}

variable "memory" {
  type    = number
  default = 512
}

variable "desired_count" {
  type    = number
  default = 1
}

variable "db_secret_arn" {
  type = string
}

variable "sqs_csv_queue_arn" {
  type = string
}

variable "s3_csv_bucket_arn" {
  type = string
}

variable "extra_environment" {
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}
