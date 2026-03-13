module "artifact_bucket" {
  source      = "../../modules/s3"
  bucket_name = var.artifact_bucket_name
}

module "vpc" {
  source      = "../../modules/vpc"
  project     = "nyc-taxi"
  environment = var.environment
  
}