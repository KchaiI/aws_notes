output "vpc_id" {
  description = "VPCのID"
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "VPCのCIDRブロック"
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "PublicサブネットのIDリスト"
  value       = aws_subnet.public[*].id
}

output "app_subnet_ids" {
  description = "AppサブネットのIDリスト"
  value       = aws_subnet.app[*].id
}

output "db_subnet_ids" {
  description = "DBサブネットのIDリスト"
  value       = aws_subnet.db[*].id
}