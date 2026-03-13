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
  description = "VPC ID where RDS will be created"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for RDS subnet group"
}

variable "eks_node_security_group_id" {
  type        = string
  description = "EKS node security group ID - allowed to connect to RDS"
}

variable "db_instance_class" {
  type        = string
  description = "RDS instance class"
  default     = "db.t3.medium"
}

variable "db_allocated_storage" {
  type        = number
  description = "Allocated storage in GB"
  default     = 20
}

variable "db_name" {
  type        = string
  description = "Name of the MLflow database"
  default     = "mlflow"
}

variable "db_username" {
  type        = string
  description = "Master username for RDS"
  default     = "mlflow"
}