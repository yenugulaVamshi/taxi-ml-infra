variable "project" {
  type        = string
  description = "Project name"
}

variable "environment" {
  type        = string
  description = "Deployment environment"
}

variable "account_id" {
  type        = string
  description = "AWS account ID"
}

variable "github_org" {
  type        = string
  description = "GitHub organization or username"
}

variable "github_infra_repo" {
  type        = string
  description = "GitHub infra repository name"
  default     = "taxi-ml-infra"
}

variable "github_training_repo" {
  type        = string
  description = "GitHub training repository name"
  default     = "taxi-ml-training"
}

variable "github_serving_repo" {
  type        = string
  description = "GitHub serving repository name"
  default     = "taxi-ml-serving"
}

variable "eks_oidc_provider_arn" {
  type        = string
  description = "OIDC provider ARN from EKS cluster"
}

variable "eks_oidc_provider_url" {
  type        = string
  description = "OIDC provider URL from EKS cluster"
}