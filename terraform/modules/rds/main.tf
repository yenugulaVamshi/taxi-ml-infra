# ─────────────────────────────────────────────
# Random password for RDS
# Stored in Secrets Manager — never in code
# ─────────────────────────────────────────────

resource "random_password" "db" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "db_password" {
  name                    = "/${var.project}/${var.environment}/rds/password"
  recovery_window_in_days = 0

  tags = {
    Name = "${var.project}-${var.environment}-rds-password"
  }
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db.result
}

# ─────────────────────────────────────────────
# Security group for RDS
# Only EKS nodes can connect on port 5432
# ─────────────────────────────────────────────

resource "aws_security_group" "rds" {
  name        = "${var.project}-${var.environment}-rds-sg"
  description = "Security group for RDS PostgreSQL"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.eks_node_security_group_id]
    description     = "Allow PostgreSQL from EKS nodes"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-${var.environment}-rds-sg"
  }
}

# ─────────────────────────────────────────────
# RDS subnet group
# RDS must span at least 2 AZs
# ─────────────────────────────────────────────

resource "aws_db_subnet_group" "this" {
  name       = "${var.project}-${var.environment}-rds-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "${var.project}-${var.environment}-rds-subnet-group"
  }
}

# ─────────────────────────────────────────────
# RDS PostgreSQL instance
# MLflow uses this as its backend store
# ─────────────────────────────────────────────

resource "aws_db_instance" "this" {
  identifier        = "${var.project}-${var.environment}-mlflow-db"
  engine            = "postgres"
  engine_version    = "15.7"
  instance_class    = var.db_instance_class
  allocated_storage = var.db_allocated_storage

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  skip_final_snapshot     = true
  deletion_protection     = false
  multi_az                = false
  publicly_accessible     = false
  storage_encrypted       = true

  tags = {
    Name = "${var.project}-${var.environment}-mlflow-db"
  }
}