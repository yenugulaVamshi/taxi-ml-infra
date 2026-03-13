# ─────────────────────────────────────────────
# ECR Repositories
# One repo per service image
# ─────────────────────────────────────────────

locals {
  repos = [
    "nyc-taxi/training",   # SageMaker training job image
    "nyc-taxi/serving",    # FastAPI prediction API
    "nyc-taxi/mlflow",     # MLflow tracking server
    "nyc-taxi/evidently",  # Drift monitoring cronjob
  ]
}

resource "aws_ecr_repository" "repos" {
  for_each             = toset(local.repos)
  name                 = each.value
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = each.value
  }
}

# Keep last 10 tagged images
# Delete untagged images after 7 days
resource "aws_ecr_lifecycle_policy" "cleanup" {
  for_each   = aws_ecr_repository.repos
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep last 10 tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["sha-", "v"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = { type = "expire" }
      }
    ]
  })
}

# Allow GitHub Actions to push images
resource "aws_ecr_repository_policy" "github_push" {
  for_each   = aws_ecr_repository.repos
  repository = each.value.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowGitHubActionsPush"
      Effect = "Allow"
      Principal = {
        AWS = var.github_actions_role_arn
      }
      Action = [
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:BatchCheckLayerAvailability",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
      ]
    }]
  })
}