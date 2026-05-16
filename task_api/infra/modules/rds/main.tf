locals {
  name_prefix = "${var.project}-${var.environment}"
}

# ──────────────────────────────────────
# セキュリティグループ（RDS用）
# ──────────────────────────────────────
resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-rds-sg"
  description = "Security group for RDS"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${local.name_prefix}-rds-sg"
  }
}

# 許可SGリストからPostgreSQLポート(5432)への接続許可
resource "aws_security_group_rule" "rds_ingress_from_allowed_sgs" {
  count                    = length(var.allowed_security_group_ids)
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = var.allowed_security_group_ids[count.index]
  security_group_id        = aws_security_group.rds.id
  description              = "PostgreSQL access from allowed SG"
}

# ──────────────────────────────────────
# DB サブネットグループ
# ──────────────────────────────────────
resource "aws_db_subnet_group" "this" {
  name       = "${local.name_prefix}-db-subnet-group"
  subnet_ids = var.db_subnet_ids

  tags = {
    Name = "${local.name_prefix}-db-subnet-group"
  }
}

# ──────────────────────────────────────
# ランダムパスワード生成
# ──────────────────────────────────────
resource "random_password" "db" {
  length  = 24
  special = true
  # RDSが許可しない記号を除外
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# ──────────────────────────────────────
# Secrets Manager（パスワード保管）
# ──────────────────────────────────────
resource "aws_secretsmanager_secret" "db" {
  name        = "${local.name_prefix}-db-credentials"
  description = "RDS credentials for ${local.name_prefix}"
  # 学習用：destroyしたら即座に消えてほしい（デフォルトは7日待機）
  recovery_window_in_days = 0

  tags = {
    Name = "${local.name_prefix}-db-credentials"
  }
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db.result
    engine   = "postgres"
    host     = aws_db_instance.this.address
    port     = aws_db_instance.this.port
    dbname   = var.db_name
  })
}

# ──────────────────────────────────────
# RDS インスタンス
# ──────────────────────────────────────
resource "aws_db_instance" "this" {
  identifier = "${local.name_prefix}-db"

  engine         = "postgres"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_allocated_storage * 2  # オートスケール上限
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  multi_az            = false
  skip_final_snapshot = true   # 学習用：destroy時にスナップショット作らない
  deletion_protection = false  # 学習用：terraform destroyで消せるように

  backup_retention_period = 1
  apply_immediately       = true

  tags = {
    Name = "${local.name_prefix}-db"
  }
}