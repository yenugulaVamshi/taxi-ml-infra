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