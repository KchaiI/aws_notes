locals {
  name_prefix = "${var.project}-${var.environment}"
}

# ──────────────────────────────────────
# セキュリティグループ(ALB用)
# ──────────────────────────────────────
resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "Security group for ALB"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP from anywhere"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name = "${local.name_prefix}-alb-sg"
  }
}

# ──────────────────────────────────────
# ALB 本体
# ──────────────────────────────────────
resource "aws_lb" "this" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false

  tags = {
    Name = "${local.name_prefix}-alb"
  }
}

# ──────────────────────────────────────
# ターゲットグループ
# ──────────────────────────────────────
resource "aws_lb_target_group" "this" {
  name        = "${local.name_prefix}-tg"
  port        = var.target_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"   # Fargateの場合は ip 必須

  health_check {
    enabled             = true
    path                = var.health_check_path
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 10
    timeout             = 5
    matcher             = "200"
  }

  # ECSタスクの再デプロイ時に、登録解除を速める
  deregistration_delay = 30

  tags = {
    Name = "${local.name_prefix}-tg"
  }
}

# ──────────────────────────────────────
# フロントエンド用ターゲットグループ
# ──────────────────────────────────────
resource "aws_lb_target_group" "frontend" {
  name        = "${local.name_prefix}-frontend-tg"
  port        = var.frontend_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = var.frontend_health_check_path
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 10
    timeout             = 5
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = {
    Name = "${local.name_prefix}-frontend-tg"
  }
}

# ──────────────────────────────────────
# リスナー (80 -> デフォルトはフロントエンド)
# ──────────────────────────────────────
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }

  tags = {
    Name = "${local.name_prefix}-listener-http"
  }
}

# ──────────────────────────────────────
# リスナールール (/api/* と /health* は API へ)
# ──────────────────────────────────────
resource "aws_lb_listener_rule" "api" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }

  condition {
    path_pattern {
      values = ["/api/*", "/health", "/health/*"]
    }
  }

  tags = {
    Name = "${local.name_prefix}-api-rule"
  }
}