================================================================
STEP 06: Terraform Worker 用インフラ（ECR + ECS + IAM）
================================================================

## 変更・作成ファイル
- task_api/infra/modules/ecr/main.tf          （Worker用リポジトリ追加）
- task_api/infra/modules/ecs/main.tf          （Workerサービス追加）
- task_api/infra/modules/ecs/variables.tf     （Worker関連変数追加）
- task_api/infra/envs/dev/main.tf             （変数・モジュール更新）

---

## ECR: Worker用リポジトリ追加

modules/ecr/main.tf に追加（既存の api_app リポジトリに並べて）：

```hcl
resource "aws_ecr_repository" "worker" {
  name                 = "${var.prefix}-worker"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}
```

---

## ECS: Worker サービスの追加

modules/ecs/main.tf に追加する主なリソース：

```hcl
# Worker用タスク定義
resource "aws_ecs_task_definition" "worker" {
  family                   = "${var.prefix}-worker"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.worker_task.arn  # Worker専用ロール

  container_definitions = jsonencode([{
    name      = "worker"
    image     = "${var.worker_ecr_image}"
    essential = true
    environment = [
      { name = "DATABASE_URL",        value = var.database_url },
      { name = "SQS_CSV_QUEUE_URL",   value = var.sqs_csv_queue_url },
      { name = "S3_CSV_BUCKET_NAME",  value = var.s3_csv_bucket_name },
      { name = "AWS_REGION",          value = "ap-northeast-1" },
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/${var.prefix}-worker"
        "awslogs-region"        = "ap-northeast-1"
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

# Worker用ECSサービス
resource "aws_ecs_service" "worker" {
  name            = "${var.prefix}-worker"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.worker.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.worker.id]
    assign_public_ip = false
  }

  # ALBへの紐付けは不要（Workerはインバウンド通信なし）
}
```

---

## IAM: Worker専用タスクロール

modules/ecs/main.tf に追加：

```hcl
# Worker用タスクロール
resource "aws_iam_role" "worker_task" {
  name = "${var.prefix}-worker-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# SQS権限（受信・削除）
resource "aws_iam_role_policy" "worker_sqs" {
  name   = "worker-sqs-policy"
  role   = aws_iam_role.worker_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes",
      ]
      Resource = var.sqs_csv_queue_arn
    }]
  })
}

# S3権限（CSV書き込みのみ）
resource "aws_iam_role_policy" "worker_s3" {
  name   = "worker-s3-policy"
  role   = aws_iam_role.worker_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:PutObject"]
      Resource = "${var.s3_csv_bucket_arn}/csv/*"
    }]
  })
}
```

---

## IAM: API サーバーのタスクロールに SQS SendMessage を追加

modules/ecs/main.tf の既存 api_task ロールに追加：

```hcl
resource "aws_iam_role_policy" "api_sqs_send" {
  name   = "api-sqs-send-policy"
  role   = aws_iam_role.api_task.id   # 既存ロール

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["sqs:SendMessage"]
      Resource = var.sqs_csv_queue_arn
    }]
  })
}
```

---

## Worker用セキュリティグループ

```hcl
resource "aws_security_group" "worker" {
  name   = "${var.prefix}-worker-sg"
  vpc_id = var.vpc_id

  # インバウンドなし（Workerは外部から呼ばれない）

  # アウトバウンド: SQS/S3/RDSへの通信を許可
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

---

## 追加する変数（variables.tf）

```hcl
variable "worker_ecr_image"     { type = string }
variable "sqs_csv_queue_url"    { type = string }
variable "sqs_csv_queue_arn"    { type = string }
variable "s3_csv_bucket_name"   { type = string }
variable "s3_csv_bucket_arn"    { type = string }
```

---

## ポイント

- Worker用のIAMロールはAPIサーバーとは別に作成（最小権限の原則）
- WorkerはALBに紐付けない（インバウンドHTTPリクエストを受け取らない）
- セキュリティグループはインバウンドなし（SQSポーリングはWorker側から発信）
- desired_count: 1（スケーリングは今回省略）
