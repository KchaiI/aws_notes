locals {
  name_prefix = "${var.project}-${var.environment}"
}

# ──────────────────────────────────────
# 最新の Amazon Linux 2023 AMI を取得（ARM）
# ──────────────────────────────────────
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-arm64"]
  }

  filter {
    name   = "architecture"
    values = ["arm64"]
  }
}

# ──────────────────────────────────────
# セキュリティグループ（踏み台用）
# ──────────────────────────────────────
resource "aws_security_group" "bastion" {
  name        = "${local.name_prefix}-bastion-sg"
  description = "Security group for bastion host (SSM only, no inbound)"
  vpc_id      = var.vpc_id

  # 受信ルールなし（SSMで接続するので22番もNAT越しも不要）

  # 送信は全許可（パッケージインストール、SSM、RDS接続のため）
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name = "${local.name_prefix}-bastion-sg"
  }
}

# ──────────────────────────────────────
# IAM ロール（SSM 接続用）
# ──────────────────────────────────────
resource "aws_iam_role" "bastion" {
  name = "${local.name_prefix}-bastion-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "${local.name_prefix}-bastion-role"
  }
}

# AWS管理ポリシー: SSM Session Manager 接続に必要
resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# インスタンスプロファイル（EC2にIAMロールを紐付ける箱）
resource "aws_iam_instance_profile" "bastion" {
  name = "${local.name_prefix}-bastion-profile"
  role = aws_iam_role.bastion.name
}

# ──────────────────────────────────────
# EC2 インスタンス（踏み台）
# ──────────────────────────────────────
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [aws_security_group.bastion.id]
  iam_instance_profile   = aws_iam_instance_profile.bastion.name

  # ユーザーデータ：PostgreSQLクライアントをインストールしておく
  user_data = <<-EOF
              #!/bin/bash
              dnf install -y postgresql15
              EOF

  # ストレージ
  root_block_device {
    volume_type = "gp3"
    volume_size = 8
    encrypted   = true
  }

  tags = {
    Name = "${local.name_prefix}-bastion"
  }
}