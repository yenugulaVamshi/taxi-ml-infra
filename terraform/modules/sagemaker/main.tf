# ─────────────────────────────────────────────
# Security group for SageMaker Studio
# ─────────────────────────────────────────────

resource "aws_security_group" "sagemaker" {
  name        = "${var.project}-${var.environment}-sagemaker-sg"
  description = "Security group for SageMaker Studio"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  tags = {
    Name = "${var.project}-${var.environment}-sagemaker-sg"
  }
}

# ─────────────────────────────────────────────
# SageMaker Studio Domain
# Uses dedicated studio execution role
# NOT the training role
# ─────────────────────────────────────────────

resource "aws_sagemaker_domain" "this" {
  domain_name = "${var.project}-${var.environment}-studio"
  auth_mode   = "IAM"
  vpc_id      = var.vpc_id
  subnet_ids  = var.private_subnet_ids

  default_user_settings {
    execution_role  = var.sagemaker_studio_role_arn
    security_groups = [aws_security_group.sagemaker.id]
  }

  tags = {
    Name = "${var.project}-${var.environment}-studio"
  }
}

# ─────────────────────────────────────────────
# SageMaker Studio User Profile
# ─────────────────────────────────────────────

resource "aws_sagemaker_user_profile" "this" {
  domain_id         = aws_sagemaker_domain.this.id
  user_profile_name = "${var.project}-${var.environment}-user"

  user_settings {
    execution_role = var.sagemaker_studio_role_arn
  }

  tags = {
    Name = "${var.project}-${var.environment}-user"
  }
}