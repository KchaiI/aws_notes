================================================================
STEP 02: Terraform SQS モジュールの作成
================================================================

## 作成ファイル
- task_api/infra/modules/sqs/main.tf
- task_api/infra/modules/sqs/variables.tf
- task_api/infra/modules/sqs/outputs.tf
- task_api/infra/envs/dev/main.tf  （モジュール呼び出し追加）

---

## modules/sqs/main.tf

```hcl
resource "aws_sqs_queue" "this" {
  name                       = var.name
  visibility_timeout_seconds = var.visibility_timeout_seconds
  message_retention_seconds  = var.message_retention_seconds

  tags = {
    Name = var.name
  }
}
```

---

## modules/sqs/variables.tf

```hcl
variable "name" {
  type = string
}

variable "visibility_timeout_seconds" {
  type    = number
  default = 300   # Worker処理の最大想定時間
}

variable "message_retention_seconds" {
  type    = number
  default = 345600  # 4日
}
```

---

## modules/sqs/outputs.tf

```hcl
output "queue_url" {
  value = aws_sqs_queue.this.url
}

output "queue_arn" {
  value = aws_sqs_queue.this.arn
}
```

---

## envs/dev/main.tf への追記

```hcl
module "sqs_csv" {
  source = "../../modules/sqs"
  name   = "csv-export-queue"
}
```

---

## IAM ポリシー追加（既存ECSタスクロールへ）

API サーバーのECSタスクロールに以下を追加：

```hcl
# SendMessageポリシー（APIサーバー用）
resource "aws_iam_role_policy" "api_sqs_send" {
  name   = "api-sqs-send"
  role   = <api_task_role_id>

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["sqs:SendMessage"]
      Resource = module.sqs_csv.queue_arn
    }]
  })
}
```

---

## ポイント

- Standard Queue を使用（FIFO不要: エクスポートリクエストは順序不問）
- visibility_timeout は Worker の処理時間より長く設定（300秒）
- DLQ（デッドレターキュー）は今回は省略（拡張課題として検討可）
