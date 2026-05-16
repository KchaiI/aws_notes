output "instance_id" {
  description = "踏み台EC2のインスタンスID（SSM接続時に使う）"
  value       = aws_instance.bastion.id
}

output "security_group_id" {
  description = "踏み台のセキュリティグループID（RDSのSGから許可するために使う）"
  value       = aws_security_group.bastion.id
}