output "cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "service_name" {
  value = aws_ecs_service.this.name
}

output "task_definition_family" {
  value = aws_ecs_task_definition.this.family
}

output "security_group_id" {
  description = "ECSタスクのSG ID(RDSのSGから許可するため)"
  value       = aws_security_group.ecs_task.id
}

output "log_group_name" {
  value = aws_cloudwatch_log_group.this.name
}