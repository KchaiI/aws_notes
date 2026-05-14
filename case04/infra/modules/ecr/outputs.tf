output "repository_url" {
  description = "ECRリポジトリのURL（docker pushの宛先になる）"
  value       = aws_ecr_repository.this.repository_url
}

output "repository_arn" {
  description = "ECRリポジトリのARN（IAMポリシーで使う）"
  value       = aws_ecr_repository.this.arn
}

output "repository_name" {
  description = "ECRリポジトリ名"
  value       = aws_ecr_repository.this.name
}