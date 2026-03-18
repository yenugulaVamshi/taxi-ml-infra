variable "project" {
  type        = string
  description = "Project name"
}

variable "environment" {
  type        = string
  description = "Deployment environment"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID for SageMaker"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for SageMaker"
}

variable "training_role_arn" {
  type        = string
  description = "IAM role ARN for SageMaker training jobs"
}

variable "artifacts_bucket" {
  type        = string
  description = "S3 bucket name for ML artifacts"
}

variable "processed_bucket" {
  type        = string
  description = "S3 bucket name for processed data"
}