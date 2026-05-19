locals {
  name_prefix = var.name_suffix != "" ? "${var.project}-${var.environment}-${var.name_suffix}" : "${var.project}-${var.environment}"
  cluster_arn = var.create_cluster ? aws_ecs_cluster.this[0].arn : var.cluster_arn
}

# ──────────────────────────────────────
# セキュリティグループ(ECSタスク用)
# ──────────────────────────────────────
resource "aws_security_group" "ecs_task" {
  name        = "${local.name_prefix}-ecs-task-sg"
  description = "Security group for ECS tasks"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = concat([var.alb_security_group_id], var.additional_ingress_sg_ids)
    content {
      from_port       = var.container_port
      to_port         = var.container_port
      protocol        = "tcp"
      security_groups = [ingress.value]
      description     = "Allow ALB to reach container port"
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name = "${local.name_prefix}-ecs-task-sg"
  }
}

# ──────────────────────────────────────
# CloudWatch Logs グループ
# ──────────────────────────────────────
resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${local.name_prefix}"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${local.name_prefix}-logs"
  }
}

# ──────────────────────────────────────
# ECS クラスター
# ──────────────────────────────────────
resource "aws_ecs_cluster" "this" {
  count = var.create_cluster ? 1 : 0
  name  = "${local.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "disabled"   # 学習用ではコスト抑制のため無効
  }

  tags = {
    Name = "${local.name_prefix}-cluster"
  }
}

# ──────────────────────────────────────
# タスク実行ロール (AWS が タスクを起動する時に使う)
# ──────────────────────────────────────
resource "aws_iam_role" "task_execution" {
  name = "${local.name_prefix}-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "${local.name_prefix}-task-execution-role"
  }
}

# AWS管理ポリシー: ECR pull、CloudWatch Logs書き込み
resource "aws_iam_role_policy_attachment" "task_execution_basic" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Secrets Manager からの取得を許可（DB接続が必要なサービスのみ）
resource "aws_iam_role_policy" "task_execution_secrets" {
  count = var.enable_db ? 1 : 0
  name  = "${local.name_prefix}-task-execution-secrets"
  role  = aws_iam_role.task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue"
      ]
      Resource = [
        var.db_secret_arn
      ]
    }]
  })
}

# ──────────────────────────────────────
# タスクロール (タスク内のアプリが使う)
# ──────────────────────────────────────
resource "aws_iam_role" "task" {
  name = "${local.name_prefix}-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "${local.name_prefix}-task-role"
  }
}

# S3 + Secrets Manager 権限（画像アップロード・Signed URL 生成用）
resource "aws_iam_role_policy" "task_s3" {
  count = var.enable_s3_access ? 1 : 0
  name  = "${local.name_prefix}-task-s3"
  role  = aws_iam_role.task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject"
        ]
        Resource = "${var.s3_bucket_arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = [var.cf_private_key_secret_arn]
      }
    ]
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

  container_definitions = jsonencode([
    {
      name      = "app"
      image     = var.container_image
      essential = true

      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]

      environment = concat(
        [
          { name = "NODE_ENV", value = "production" },
          { name = "PORT",     value = tostring(var.container_port) },
          { name = "HOST",     value = "0.0.0.0" },
        ],
        var.enable_db ? [
          { name = "DB_HOST", value = var.db_endpoint },
          { name = "DB_PORT", value = tostring(var.db_port) },
          { name = "DB_NAME", value = var.db_name },
        ] : [],
        var.extra_environment
      )

      secrets = var.enable_db ? [
        {
          name      = "DB_USER"
          valueFrom = "${var.db_secret_arn}:username::"
        },
        {
          name      = "DB_PASSWORD"
          valueFrom = "${var.db_secret_arn}:password::"
        }
      ] : []

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.this.name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "app"
        }
      }
    }
  ])

  tags = {
    Name = "${local.name_prefix}-task"
  }
}

# 現在のリージョンを取得
data "aws_region" "current" {}

# ──────────────────────────────────────
# ECS サービス
# ──────────────────────────────────────
resource "aws_ecs_service" "this" {
  name            = "${local.name_prefix}-service"
  cluster         = local.cluster_arn
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.app_subnet_ids
    security_groups  = [aws_security_group.ecs_task.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.alb_target_group_arn
    container_name   = "app"
    container_port   = var.container_port
  }

  dynamic "load_balancer" {
    for_each = var.register_to_internal_alb ? ["internal"] : []
    content {
      target_group_arn = var.internal_alb_target_group_arn
      container_name   = "app"
      container_port   = var.container_port
    }
  }

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  # Fastify は 1s 以内に起動するため短めに設定（ALB health check: interval=10s, threshold=2 → 20s で healthy）
  health_check_grace_period_seconds = 15

  # タスク定義はCDで更新するので、Terraformが上書きしないようにignore
  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }

  tags = {
    Name = "${local.name_prefix}-service"
  }
}