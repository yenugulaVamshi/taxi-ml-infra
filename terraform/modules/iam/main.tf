# ─────────────────────────────────────────────
# GitHub OIDC Provider
# Allows GitHub Actions to authenticate to AWS
# without storing any long-lived credentials
# ─────────────────────────────────────────────

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# GitHub Actions IAM role
# Only repos in your GitHub org can assume this role
resource "aws_iam_role" "github_actions" {
  name = "${var.project}-${var.environment}-github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringLike = {
            "token.actions.githubusercontent.com:sub" = [
              "repo:${var.github_org}/${var.github_infra_repo}:*",
              "repo:${var.github_org}/${var.github_training_repo}:*",
              "repo:${var.github_org}/${var.github_serving_repo}:*",
            ]
          }
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

# GitHub Actions permissions
resource "aws_iam_role_policy" "github_actions" {
  name = "${var.project}-${var.environment}-github-actions-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRAuth"
        Effect = "Allow"
        Action = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "ECRPush"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
        ]
        Resource = "arn:aws:ecr:*:${var.account_id}:repository/${var.project}/*"
      },
      {
        Sid    = "S3DAGSync"
        Effect = "Allow"
        Action = ["s3:PutObject", "s3:GetObject", "s3:ListBucket", "s3:DeleteObject"]
        Resource = [
          "arn:aws:s3:::${var.project}-${var.environment}-mwaa-dags",
          "arn:aws:s3:::${var.project}-${var.environment}-mwaa-dags/*",
        ]
      },
      {
        Sid    = "EKSDeploy"
        Effect = "Allow"
        Action = ["eks:DescribeCluster"]
        Resource = "arn:aws:eks:*:${var.account_id}:cluster/${var.project}-${var.environment}-cluster"
      }
    ]
  })
}

# ─────────────────────────────────────────────
# IRSA — MLflow pod role
# MLflow needs to read/write S3 artifacts
# and read RDS password from Secrets Manager
# ─────────────────────────────────────────────

resource "aws_iam_role" "mlflow" {
  name = "${var.project}-${var.environment}-mlflow-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = var.eks_oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${var.eks_oidc_provider_url}:sub" = "system:serviceaccount:mlflow:mlflow-sa"
          "${var.eks_oidc_provider_url}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "mlflow" {
  name = "${var.project}-${var.environment}-mlflow-policy"
  role = aws_iam_role.mlflow.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3Artifacts"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:ListBucket", "s3:DeleteObject"]
        Resource = [
          "arn:aws:s3:::${var.project}-${var.environment}-artifacts",
          "arn:aws:s3:::${var.project}-${var.environment}-artifacts/*",
        ]
      },
      {
        Sid    = "SecretsManager"
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue"]
        Resource = "arn:aws:secretsmanager:*:${var.account_id}:secret:/${var.project}/*"
      }
    ]
  })
}

# ─────────────────────────────────────────────
# IRSA — Serving pod role
# FastAPI needs to read models from S3
# ─────────────────────────────────────────────

resource "aws_iam_role" "serving" {
  name = "${var.project}-${var.environment}-serving-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = var.eks_oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${var.eks_oidc_provider_url}:sub" = "system:serviceaccount:serving:serving-sa"
          "${var.eks_oidc_provider_url}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "serving" {
  name = "${var.project}-${var.environment}-serving-policy"
  role = aws_iam_role.serving.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "S3Models"
      Effect = "Allow"
      Action = ["s3:GetObject", "s3:ListBucket"]
      Resource = [
        "arn:aws:s3:::${var.project}-${var.environment}-artifacts",
        "arn:aws:s3:::${var.project}-${var.environment}-artifacts/*",
      ]
    }]
  })
}

# ─────────────────────────────────────────────
# SageMaker training role
# Training jobs need to read processed data
# and write model artifacts to S3
# ─────────────────────────────────────────────

resource "aws_iam_role" "training" {
  name = "${var.project}-${var.environment}-training-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "sagemaker.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "training" {
  name = "${var.project}-${var.environment}-training-policy"
  role = aws_iam_role.training.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3Access"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
        Resource = [
          "arn:aws:s3:::${var.project}-${var.environment}-processed",
          "arn:aws:s3:::${var.project}-${var.environment}-processed/*",
          "arn:aws:s3:::${var.project}-${var.environment}-artifacts",
          "arn:aws:s3:::${var.project}-${var.environment}-artifacts/*",
        ]
      },
      {
        Sid    = "ECRAccess"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "*"
      }
    ]
  })
}