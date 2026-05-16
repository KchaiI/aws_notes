variable "project" {
  type        = string
  description = "プロジェクト名"
}

variable "environment" {
  type        = string
  description = "環境名"
}

variable "github_owner" {
  type        = string
  description = "GitHubのユーザー名またはOrganization名"
}

variable "github_repo" {
  type        = string
  description = "GitHubのリポジトリ名"
}

variable "allowed_branches" {
  type        = list(string)
  description = "デプロイを許可するブランチ"
  default     = ["main"]
}

variable "ecr_repository_arn" {
  type        = string
  description = "ECRリポジトリのARN"
}

variable "ecs_cluster_arn" {
  type        = string
  description = "ECSクラスターのARN"
}

variable "ecs_service_arn" {
  type        = string
  description = "ECSサービスのARN"
}

variable "task_execution_role_arn" {
  type        = string
  description = "タスク実行ロールのARN(PassRoleで渡すため)"
}

variable "task_role_arn" {
  type        = string
  description = "タスクロールのARN(PassRoleで渡すため)"
}