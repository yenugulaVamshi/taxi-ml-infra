output "github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions"
  value       = aws_iam_role.github_actions.arn
}

output "mlflow_role_arn" {
  description = "IAM role ARN for MLflow pod"
  value       = aws_iam_role.mlflow.arn
}

output "serving_role_arn" {
  description = "IAM role ARN for serving pod"
  value       = aws_iam_role.serving.arn
}

output "training_role_arn" {
  description = "IAM role ARN for SageMaker training jobs"
  value       = aws_iam_role.training.arn
}

output "sagemaker_studio_role_arn" {
  description = "IAM role ARN for SageMaker Studio execution"
  value       = aws_iam_role.sagemaker_studio.arn
}

output "external_secrets_role_arn" {
  description = "IAM role ARN for External Secrets Operator"
  value       = aws_iam_role.external_secrets.arn
}