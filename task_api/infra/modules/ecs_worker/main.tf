locals {
  name_prefix = "${var.project}-${var.environment}-worker"
}

data "aws_region" "current" {}

# ──────────────────────────────────────
# セキュリティグループ（インバウンドなし）
# ──────────────────────────────────────
resource "aws_security_group" "this" {
  name        = "${local.name_prefix}-sg"
  description = "Security group for Worker ECS tasks"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound (SQS/S3/RDS)"
  }

  tags = {
    Name = "${local.name_prefix}-sg"
  }
}

# ──────────────────────────────────────
# CloudWatch Logs グループ
# ──────────────────────────────────────
resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${local.name_prefix}"
  retention_in_days = 7

  tags = {
    Name = "${local.name_prefix}-logs"
  }
}

# ──────────────────────────────────────
# タスク実行ロール
# ──────────────────────────────────────
resource "aws_iam_role" "task_execution" {
  name = "${local.name_prefix}-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "${local.name_prefix}-task-execution-role"
  }
}

resource "aws_iam_role_policy_attachment" "task_execution_basic" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Secrets Manager からDB認証情報を取得する権限
resource "aws_iam_role_policy" "task_execution_secrets" {
  name = "${local.name_prefix}-task-execution-secrets"
  role = aws_iam_role.task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = [var.db_secret_arn]
    }]
  })
}

# ──────────────────────────────────────
# タスクロール（SQS受信・削除 + S3書き込み）
# ──────────────────────────────────────
resource "aws_iam_role" "task" {
  name = "${local.name_prefix}-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "${local.name_prefix}-task-role"
  }
}

resource "aws_iam_role_policy" "task_sqs" {
  name = "${local.name_prefix}-task-sqs"
  role = aws_iam_role.task.id

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

resource "aws_iam_role_policy" "task_s3" {
  name = "${local.name_prefix}-task-s3"
  role = aws_iam_role.task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:PutObject"]
      Resource = "${var.s3_csv_bucket_arn}/csv/*"
    }]
  })
}

# ──────────────────────────────────────
# タスク定義
# ──────────────────────────────────────
resource "aws_ecs_task_definition" "this" {
  family                   = "${local.name_prefix}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory

  execution_role_arn = aws_iam_role.task_execution.arn
  task_role_arn      = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([{
    name      = "worker"
    image     = var.container_image
    essential = true

    environment = concat(
      [
        { name = "NODE_ENV",  value = "production" },
        { name = "DB_PORT",   value = "5432" },
      ],
      var.extra_environment
    )

    secrets = [
      { name = "DB_USER",     valueFrom = "${var.db_secret_arn}:username::" },
      { name = "DB_PASSWORD", valueFrom = "${var.db_secret_arn}:password::" },
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.this.name
        awslogs-region        = data.aws_region.current.name
        awslogs-stream-prefix = "worker"
      }
    }
  }])

  tags = {
    Name = "${local.name_prefix}-task"
  }
}

# ──────────────────────────────────────
# ECS サービス（ALBなし）
# ──────────────────────────────────────
resource "aws_ecs_service" "this" {
  name            = "${local.name_prefix}-service"
  cluster         = var.cluster_arn
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.app_subnet_ids
    security_groups  = [aws_security_group.this.id]
    assign_public_ip = false
  }

  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }

  tags = {
    Name = "${local.name_prefix}-service"
  }
}
