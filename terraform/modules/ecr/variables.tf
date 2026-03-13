variable "project" {
  type        = string
  description = "Project name"
}

variable "environment" {
  type        = string
  description = "Deployment environment"
}

variable "github_actions_role_arn" {
  type        = string
  description = "IAM role ARN for GitHub Actions to push images"
}