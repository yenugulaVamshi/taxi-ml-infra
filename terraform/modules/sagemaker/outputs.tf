output "domain_id" {
  description = "SageMaker Studio domain ID"
  value       = aws_sagemaker_domain.this.id
}

output "domain_arn" {
  description = "SageMaker Studio domain ARN"
  value       = aws_sagemaker_domain.this.arn
}

output "execution_role_arn" {
  description = "SageMaker execution role ARN"
  value       = var.training_role_arn
}