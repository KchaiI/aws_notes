locals {
  name_prefix = "${var.project}-${var.environment}"
}

# ──────────────────────────────────────
# CloudWatch Insights 保存クエリ
#
# 設計:
#   pino は JSON で level を数値出力する（50=error, 40=warn, 30=info）
#   filter level >= 50 だけでサーバーエラーを抽出できる
#   reqId でリクエストログとエラーログを紐付けてデバッグ可能
# ──────────────────────────────────────
resource "aws_cloudwatch_query_definition" "error_logs" {
  name            = "${local.name_prefix}/server-errors"
  log_group_names = [var.log_group_name]

  query_string = <<-EOT
    fields @timestamp, msg, level, err.message, reqId, statusCode, method, url
    | filter level >= 50
    | sort @timestamp desc
    | limit 100
  EOT
}

# warn 以上（4xx + 5xx）を一覧したい時用
resource "aws_cloudwatch_query_definition" "warn_logs" {
  name            = "${local.name_prefix}/warn-and-errors"
  log_group_names = [var.log_group_name]

  query_string = <<-EOT
    fields @timestamp, msg, level, statusCode, method, url, err.message, reqId
    | filter level >= 40
    | sort @timestamp desc
    | limit 100
  EOT
}

# ──────────────────────────────────────
# SNS トピック（CloudWatch Alarm の通知先）
# ──────────────────────────────────────
resource "aws_sns_topic" "alarms" {
  name = "${local.name_prefix}-alarms"

  tags = {
    Name = "${local.name_prefix}-alarms"
  }
}

# ──────────────────────────────────────
# Lambda 関数（SNS → Slack Webhook 通知）
# ──────────────────────────────────────

# Lambda の実行ロール
resource "aws_iam_role" "lambda_slack" {
  name = "${local.name_prefix}-lambda-slack-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "${local.name_prefix}-lambda-slack-role"
  }
}

# CloudWatch Logs へのログ書き込みを許可
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_slack.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda コードを inline で zip 化
data "archive_file" "slack_notifier" {
  type        = "zip"
  output_path = "/tmp/slack_notifier.zip"

  source {
    filename = "index.py"
    content  = <<-PYTHON
      import json
      import os
      import urllib.request
      import time

      def handler(event, context):
          webhook_url = os.environ["SLACK_WEBHOOK_URL"]

          for record in event.get("Records", []):
              sns_message = json.loads(record["Sns"]["Message"])

              alarm_name  = sns_message.get("AlarmName", "Unknown Alarm")
              new_state   = sns_message.get("NewStateValue", "UNKNOWN")
              old_state   = sns_message.get("OldStateValue", "UNKNOWN")
              reason      = sns_message.get("NewStateReason", "")
              region      = sns_message.get("Region", "")
              metric_name = sns_message.get("Trigger", {}).get("MetricName", "")

              if new_state == "ALARM":
                  color  = "danger"
                  status = ":rotating_light: *ALARM*"
              elif new_state == "OK":
                  color  = "good"
                  status = ":white_check_mark: *OK* (回復)"
              else:
                  color  = "warning"
                  status = f":warning: *{new_state}*"

              payload = {
                  "attachments": [{
                      "color": color,
                      "title": f"CloudWatch Alarm: {alarm_name}",
                      "fields": [
                          {"title": "状態",     "value": f"{old_state} → {status}", "short": True},
                          {"title": "メトリクス", "value": metric_name,                "short": True},
                          {"title": "リージョン", "value": region,                    "short": True},
                      ],
                      "text": reason,
                      "footer": "CloudWatch Alarm",
                      "ts": int(time.time()),
                  }]
              }

              data = json.dumps(payload).encode("utf-8")
              req  = urllib.request.Request(
                  webhook_url,
                  data=data,
                  headers={"Content-Type": "application/json"},
                  method="POST",
              )
              urllib.request.urlopen(req)

          return {"statusCode": 200}
    PYTHON
  }
}

resource "aws_lambda_function" "slack_notifier" {
  function_name = "${local.name_prefix}-slack-notifier"
  role          = aws_iam_role.lambda_slack.arn
  runtime       = "python3.12"
  handler       = "index.handler"

  filename         = data.archive_file.slack_notifier.output_path
  source_code_hash = data.archive_file.slack_notifier.output_base64sha256

  environment {
    variables = {
      SLACK_WEBHOOK_URL = var.slack_webhook_url
    }
  }

  tags = {
    Name = "${local.name_prefix}-slack-notifier"
  }
}

# SNS が Lambda を呼び出せるよう許可
resource "aws_lambda_permission" "sns_invoke" {
  statement_id  = "AllowSNSInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.slack_notifier.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.alarms.arn
}

# SNS → Lambda のサブスクリプション
resource "aws_sns_topic_subscription" "lambda" {
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.slack_notifier.arn
}

# ──────────────────────────────────────
# CloudWatch Alarm: ECS CPU 使用率
#
# 閾値を 1% に設定する理由:
#   Fargate のアイドル時 CPU は 0.1〜0.5% 程度。
#   5% では通常負荷でも発火しないため、学習・動作確認用に 1% に下げる。
# ──────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  alarm_name          = "${local.name_prefix}-ecs-cpu-high"
  alarm_description   = "ECS CPU 使用率が ${var.cpu_alarm_threshold}% を超えました (cluster: ${var.cluster_name})"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = var.cpu_alarm_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = var.cluster_name
    ServiceName = var.service_name
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]

  tags = {
    Name = "${local.name_prefix}-ecs-cpu-high"
  }
}
