output "lambda_function_name" {
  value = aws_lambda_function.slack_notify.function_name
}

output "state_machine_arn" {
  value = aws_sfn_state_machine.main.arn
}

output "eventbridge_rule_name" {
  value = aws_cloudwatch_event_rule.schedule.name
}
