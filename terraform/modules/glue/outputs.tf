output "feature_job_name" {
  description = "Glue feature engineering job name"
  value       = aws_glue_job.feature_engineering.name
}

output "glue_role_arn" {
  description = "IAM role ARN for Glue jobs"
  value       = aws_iam_role.glue.arn
}

output "scripts_bucket" {
  description = "S3 bucket for Glue scripts"
  value       = aws_s3_bucket.glue_scripts.bucket
}