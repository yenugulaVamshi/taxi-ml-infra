variable "aws_region" {
  type        = string
  description = "AWS region to deploy into"
}

variable "artifact_bucket_name" {
  type        = string
  description = "S3 bucket name for ML artifacts"
}

variable "environment" {
  type        = string
  description = "Deployment environment"
  default     = "dev"
}

variable "account_id" {
  type        = string
  description = "AWS account ID"
}

variable "github_org" {
  type        = string
  description = "GitHub organization or username"
}