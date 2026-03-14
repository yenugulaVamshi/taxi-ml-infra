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
  description = "VPC ID where MWAA will be created"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for MWAA environment"
}

variable "mwaa_execution_role_arn" {
  type        = string
  description = "IAM role ARN for MWAA execution"
  default     = ""
}

variable "airflow_version" {
  type        = string
  description = "Apache Airflow version"
  default     = "2.9.2"
}

variable "environment_class" {
  type        = string
  description = "MWAA environment class"
  default     = "mw1.small"
}

variable "max_workers" {
  type        = number
  description = "Maximum number of workers"
  default     = 2
}

variable "min_workers" {
  type        = number
  description = "Minimum number of workers"
  default     = 1
}