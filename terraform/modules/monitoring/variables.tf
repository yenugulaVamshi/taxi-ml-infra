variable "project" {
  type        = string
  description = "Project name"
}

variable "environment" {
  type        = string
  description = "Deployment environment"
}

variable "alert_email" {
  type        = string
  description = "Email address for CloudWatch alerts"
}

variable "rds_instance_id" {
  type        = string
  description = "RDS instance identifier for monitoring"
}

variable "eks_cluster_name" {
  type        = string
  description = "EKS cluster name for monitoring"
}