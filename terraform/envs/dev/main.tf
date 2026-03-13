module "artifact_bucket" {
  source      = "../../modules/s3"
  bucket_name = var.artifact_bucket_name
}

module "vpc" {
  source      = "../../modules/vpc"
  project     = "nyc-taxi"
  environment = var.environment
}

module "eks" {
  source             = "../../modules/eks"
  project            = "nyc-taxi"
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
}