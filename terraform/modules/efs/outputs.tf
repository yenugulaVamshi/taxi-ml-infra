output "efs_id" {
  description = "EFS filesystem ID"
  value       = aws_efs_file_system.this.id
}

output "efs_dns_name" {
  description = "EFS DNS name for mounting"
  value       = aws_efs_file_system.this.dns_name
}

output "efs_security_group_id" {
  description = "EFS security group ID"
  value       = aws_security_group.efs.id
}