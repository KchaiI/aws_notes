locals {
  name_prefix = "${var.project}-${var.environment}"
}

# ──────────────────────────────────────
# セキュリティグループ (Internal ALB 用)
# ──────────────────────────────────────
resource "aws_security_group" "internal_alb" {
  name        = "${local.name_prefix}-internal-alb-sg"
  description = "Security group for Internal ALB"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.allowed_security_group_ids
    content {
      from_port       = 80
      to_port         = 80
      protocol        = "tcp"
      security_groups = [ingress.value]
      description     = "Allow HTTP from ECS tasks"
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
    Name = "${local.name_prefix}-internal-alb-sg"
  }
}

# ──────────────────────────────────────
# Internal ALB 本体
# ──────────────────────────────────────
resource "aws_lb" "internal" {
  name               = "${local.name_prefix}-internal-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.internal_alb.id]
  subnets            = var.app_subnet_ids

  enable_deletion_protection = false

  tags = {
    Name = "${local.name_prefix}-internal-alb"
  }
}

# ──────────────────────────────────────
# ターゲットグループ (API ECS 向け)
# ──────────────────────────────────────
resource "aws_lb_target_group" "api" {
  name        = "${local.name_prefix}-internal-api-tg"
  port        = var.api_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = "/health"
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
    Name = "${local.name_prefix}-internal-api-tg"
  }
}

# ──────────────────────────────────────
# リスナー (80 -> API ターゲットグループ)
# ──────────────────────────────────────
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.internal.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }

  tags = {
    Name = "${local.name_prefix}-internal-listener-http"
  }
}
