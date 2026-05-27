output "sns_topic_arn" {
  value       = aws_sns_topic.alarms.arn
  description = "アラーム通知 SNS トピック ARN"
}

output "cpu_alarm_arn" {
  value       = aws_cloudwatch_metric_alarm.ecs_cpu_high.arn
  description = "CPU 使用率アラーム ARN"
}

output "lambda_function_name" {
  value       = aws_lambda_function.slack_notifier.function_name
  description = "Slack 通知 Lambda 関数名"
}
