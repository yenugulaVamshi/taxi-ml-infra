provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project = "nyc-taxi"
      Env     = "dev"
      Managed = "terraform"
    }
  }
}
