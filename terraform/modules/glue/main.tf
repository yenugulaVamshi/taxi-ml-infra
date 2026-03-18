# ─────────────────────────────────────────────
# S3 bucket for Glue scripts
# ─────────────────────────────────────────────

resource "aws_s3_bucket" "glue_scripts" {
  bucket = "${var.project}-${var.environment}-glue-scripts"

  tags = {
    Name = "${var.project}-${var.environment}-glue-scripts"
  }
}

resource "aws_s3_bucket_versioning" "glue_scripts" {
  bucket = aws_s3_bucket.glue_scripts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "glue_scripts" {
  bucket = aws_s3_bucket.glue_scripts.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "glue_scripts" {
  bucket                  = aws_s3_bucket.glue_scripts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ─────────────────────────────────────────────
# IAM role for Glue jobs
# ─────────────────────────────────────────────

resource "aws_iam_role" "glue" {
  name = "${var.project}-${var.environment}-glue-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "glue.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.glue.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy" "glue_s3" {
  name = "${var.project}-${var.environment}-glue-s3-policy"
  role = aws_iam_role.glue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3Access"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
        ]
        Resource = [
          "arn:aws:s3:::${var.raw_bucket}",
          "arn:aws:s3:::${var.raw_bucket}/*",
          "arn:aws:s3:::${var.processed_bucket}",
          "arn:aws:s3:::${var.processed_bucket}/*",
          "arn:aws:s3:::${var.scripts_bucket}",
          "arn:aws:s3:::${var.scripts_bucket}/*",
          aws_s3_bucket.glue_scripts.arn,
          "${aws_s3_bucket.glue_scripts.arn}/*",
        ]
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = "*"
      }
    ]
  })
}

# ─────────────────────────────────────────────
# Glue Database
# ─────────────────────────────────────────────

resource "aws_glue_catalog_database" "this" {
  name = "${var.project}_${var.environment}"

  description = "Glue catalog database for NYC Taxi ML pipeline"
}

# ─────────────────────────────────────────────
# Glue Feature Engineering Job
# Triggered by Airflow DAG 03
# Reads raw TLC data → engineers features → writes processed data
# ─────────────────────────────────────────────

resource "aws_glue_job" "feature_engineering" {
  name         = "${var.project}-${var.environment}-feature-engineering"
  role_arn     = aws_iam_role.glue.arn
  glue_version = var.glue_version

  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.glue_scripts.bucket}/scripts/feature_engineering.py"
    python_version  = "3"
  }

  default_arguments = {
    "--job-language"                     = "python"
    "--job-bookmark-option"              = "job-bookmark-enable"
    "--enable-metrics"                   = "true"
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-spark-ui"                  = "true"
    "--TempDir"                          = "s3://${aws_s3_bucket.glue_scripts.bucket}/tmp/"
    "--RAW_BUCKET"                       = var.raw_bucket
    "--PROCESSED_BUCKET"                 = var.processed_bucket
  }

  worker_type       = var.worker_type
  number_of_workers = var.number_of_workers

  execution_property {
    max_concurrent_runs = 1
  }

  tags = {
    Name = "${var.project}-${var.environment}-feature-engineering"
  }
}