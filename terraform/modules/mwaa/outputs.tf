output "mwaa_arn" {
  description = "ARN of the MWAA environment"
  value       = aws_mwaa_environment.this.arn
}

output "mwaa_webserver_url" {
  description = "Webserver URL of the MWAA environment"
  value       = aws_mwaa_environment.this.webserver_url
}

output "dag_bucket_name" {
  description = "S3 bucket name for DAGs"
  value       = aws_s3_bucket.dags.bucket
}

output "dag_bucket_arn" {
  description = "S3 bucket ARN for DAGs"
  value       = aws_s3_bucket.dags.arn
}

output "mwaa_security_group_id" {
  description = "Security group ID for MWAA"
  value       = aws_security_group.mwaa.id
}