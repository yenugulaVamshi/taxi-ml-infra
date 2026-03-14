# ─────────────────────────────────────────────
# S3 bucket for DAGs
# GitHub Actions syncs DAGs here
# MWAA reads DAGs from here
# ─────────────────────────────────────────────

resource "aws_s3_bucket" "dags" {
  bucket = "${var.project}-${var.environment}-mwaa-dags"

  tags = {
    Name = "${var.project}-${var.environment}-mwaa-dags"
  }
}

resource "aws_s3_bucket_versioning" "dags" {
  bucket = aws_s3_bucket.dags.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "dags" {
  bucket = aws_s3_bucket.dags.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "dags" {
  bucket                  = aws_s3_bucket.dags.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ─────────────────────────────────────────────
# IAM role for MWAA
# ─────────────────────────────────────────────

resource "aws_iam_role" "mwaa" {
  name = "${var.project}-${var.environment}-mwaa-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = [
            "airflow.amazonaws.com",
            "airflow-env.amazonaws.com"
          ]
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "mwaa" {
  name = "${var.project}-${var.environment}-mwaa-policy"
  role = aws_iam_role.mwaa.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3DAGs"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:ListBucket",
          "s3:ListBucketVersions",
          "s3:GetBucketLocation",
          "s3:GetAccountPublicAccessBlock",
          "s3:GetBucketPublicAccessBlock",
          "s3:GetBucketAcl",
        ]
        Resource = [
          aws_s3_bucket.dags.arn,
          "${aws_s3_bucket.dags.arn}/*",
          "*",
        ]
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:GetLogEvents",
          "logs:GetLogRecord",
          "logs:GetLogDelivery",
          "logs:ListLogDeliveries",
        ]
        Resource = "*"
      },
      {
        Sid    = "SageMakerTrigger"
        Effect = "Allow"
        Action = [
          "sagemaker:CreateTrainingJob",
          "sagemaker:DescribeTrainingJob",
          "sagemaker:StopTrainingJob",
          "sagemaker:CreateHyperParameterTuningJob",
          "sagemaker:DescribeHyperParameterTuningJob",
        ]
        Resource = "*"
      },
      {
        Sid    = "GlueJobs"
        Effect = "Allow"
        Action = [
          "glue:StartJobRun",
          "glue:GetJobRun",
          "glue:GetJobRuns",
          "glue:BatchStopJobRun",
        ]
        Resource = "*"
      },
      {
        Sid    = "AirflowUI"
        Effect = "Allow"
        Action = [
          "airflow:PublishMetrics",
          "airflow:GetEnvironment",
        ]
        Resource = "*"
      },
      {
        Sid      = "SecretsManager"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = "*"
      },
      {
        Sid    = "SQS"
        Effect = "Allow"
        Action = [
          "sqs:ChangeMessageVisibility",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:ReceiveMessage",
          "sqs:SendMessage",
        ]
        Resource = "arn:aws:sqs:us-east-1:*:airflow-celery-*"
      },
      {
        Sid    = "KMS"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKey*",
          "kms:Encrypt",
        ]
        Resource = "*"
      }
    ]
  })
}

# ─────────────────────────────────────────────
# Security group for MWAA
# ─────────────────────────────────────────────

resource "aws_security_group" "mwaa" {
  name        = "${var.project}-${var.environment}-mwaa-sg"
  description = "Security group for MWAA environment"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
    description = "Allow all traffic within MWAA security group"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-${var.environment}-mwaa-sg"
  }
}

# ─────────────────────────────────────────────
# MWAA Environment
# ─────────────────────────────────────────────

resource "aws_mwaa_environment" "this" {
  name                  = "${var.project}-${var.environment}-airflow"
  airflow_version       = var.airflow_version
  environment_class     = var.environment_class
  execution_role_arn    = aws_iam_role.mwaa.arn
  webserver_access_mode = "PUBLIC_ONLY"

  source_bucket_arn    = aws_s3_bucket.dags.arn
  dag_s3_path          = "dags/"
  requirements_s3_path = "requirements.txt"

  network_configuration {
    security_group_ids = [aws_security_group.mwaa.id]
    subnet_ids         = var.private_subnet_ids
  }

  logging_configuration {
    dag_processing_logs {
      enabled   = true
      log_level = "INFO"
    }
    scheduler_logs {
      enabled   = true
      log_level = "INFO"
    }
    task_logs {
      enabled   = true
      log_level = "INFO"
    }
    webserver_logs {
      enabled   = true
      log_level = "INFO"
    }
    worker_logs {
      enabled   = true
      log_level = "INFO"
    }
  }

  airflow_configuration_options = {
    "core.default_timezone"           = "utc"
    "core.parallelism"                = "10"
    "scheduler.dag_dir_list_interval" = "30"
  }

  tags = {
    Name = "${var.project}-${var.environment}-airflow"
  }

  depends_on = [
    aws_s3_bucket_versioning.dags,
    aws_s3_bucket_public_access_block.dags,
    aws_iam_role_policy.mwaa,
  ]
}