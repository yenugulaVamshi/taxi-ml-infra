variable "project" {
  type        = string
  description = "Project name"
}

variable "environment" {
  type        = string
  description = "Deployment environment"
}

variable "raw_bucket" {
  type        = string
  description = "S3 bucket name for raw data"
}

variable "processed_bucket" {
  type        = string
  description = "S3 bucket name for processed data"
}

variable "scripts_bucket" {
  type        = string
  description = "S3 bucket name for Glue scripts"
}

variable "glue_version" {
  type        = string
  description = "AWS Glue version"
  default     = "4.0"
}

variable "worker_type" {
  type        = string
  description = "Glue worker type"
  default     = "G.1X"
}

variable "number_of_workers" {
  type        = number
  description = "Number of Glue workers"
  default     = 2
}