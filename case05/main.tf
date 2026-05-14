terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ----------------------------------------
# Lambda関数: Slack通知
# ----------------------------------------
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/index.py"
  output_path = "${path.module}/lambda/function.zip"
}

resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_cloudwatch_log_group" "lambda_log" {
  name              = "/aws/lambda/${var.project_name}-notify"
  retention_in_days = 14
}

resource "aws_lambda_function" "slack_notify" {
  function_name    = "${var.project_name}-notify"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 10

  environment {
    variables = {
      SLACK_WEBHOOK_URL = var.slack_webhook_url
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda_log]
}

# ----------------------------------------
# Step Functions ステートマシン
# ----------------------------------------
resource "aws_iam_role" "sfn_role" {
  name = "${var.project_name}-sfn-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "states.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "sfn_lambda_invoke" {
  name = "${var.project_name}-sfn-lambda-invoke"
  role = aws_iam_role.sfn_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "lambda:InvokeFunction"
      Resource = aws_lambda_function.slack_notify.arn
    }]
  })
}

resource "aws_cloudwatch_log_group" "sfn_log" {
  name              = "/aws/states/${var.project_name}-statemachine"
  retention_in_days = 14
}

resource "aws_iam_role_policy" "sfn_logs" {
  name = "${var.project_name}-sfn-logs"
  role = aws_iam_role.sfn_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogDelivery",
        "logs:GetLogDelivery",
        "logs:UpdateLogDelivery",
        "logs:DeleteLogDelivery",
        "logs:ListLogDeliveries",
        "logs:PutResourcePolicy",
        "logs:DescribeResourcePolicies",
        "logs:DescribeLogGroups"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_sfn_state_machine" "main" {
  name     = "${var.project_name}-statemachine"
  role_arn = aws_iam_role.sfn_role.arn

  definition = jsonencode({
    Comment = "EventBridge -> Step Functions -> Lambda -> Slack"
    StartAt = "NotifySlack"
    States = {
      NotifySlack = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.slack_notify.arn
          "Payload.$"  = "$"
        }
        Retry = [{
          ErrorEquals     = ["States.ALL"]
          IntervalSeconds = 2
          MaxAttempts     = 3
          BackoffRate     = 2.0
        }]
        End = true
      }
    }
  })

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.sfn_log.arn}:*"
    include_execution_data = true
    level                  = "ALL"
  }
}

# ----------------------------------------
# EventBridge ルール (スケジュール実行)
# ----------------------------------------
resource "aws_cloudwatch_event_rule" "schedule" {
  name                = "${var.project_name}-schedule"
  description         = "Trigger Step Functions on schedule"
  schedule_expression = var.schedule_expression
}

resource "aws_iam_role" "eventbridge_role" {
  name = "${var.project_name}-eventbridge-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "events.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "eventbridge_sfn_invoke" {
  name = "${var.project_name}-eventbridge-sfn-invoke"
  role = aws_iam_role.eventbridge_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "states:StartExecution"
      Resource = aws_sfn_state_machine.main.arn
    }]
  })
}

resource "aws_cloudwatch_event_target" "sfn_target" {
  rule     = aws_cloudwatch_event_rule.schedule.name
  arn      = aws_sfn_state_machine.main.arn
  role_arn = aws_iam_role.eventbridge_role.arn

  input = jsonencode({
    message = "test"
  })
}
