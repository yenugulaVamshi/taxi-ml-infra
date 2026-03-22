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

module "iam" {
  source                = "../../modules/iam"
  project               = "nyc-taxi"
  environment           = var.environment
  account_id            = var.account_id
  github_org            = var.github_org
  eks_oidc_provider_arn = module.eks.oidc_provider_arn
  eks_oidc_provider_url = module.eks.oidc_provider_url
}

module "ecr" {
  source                  = "../../modules/ecr"
  project                 = "nyc-taxi"
  environment             = var.environment
  github_actions_role_arn = module.iam.github_actions_role_arn
}

module "rds" {
  source                     = "../../modules/rds"
  project                    = "nyc-taxi"
  environment                = var.environment
  vpc_id                     = module.vpc.vpc_id
  vpc_cidr                   = module.vpc.vpc_cidr
  private_subnet_ids         = module.vpc.private_subnet_ids
  eks_node_security_group_id = module.eks.node_security_group_id
}

module "sagemaker" {
  source                    = "../../modules/sagemaker"
  project                   = "nyc-taxi"
  environment               = var.environment
  vpc_id                    = module.vpc.vpc_id
  private_subnet_ids        = module.vpc.private_subnet_ids
  training_role_arn         = module.iam.training_role_arn
  sagemaker_studio_role_arn = module.iam.sagemaker_studio_role_arn
  artifacts_bucket          = module.artifact_bucket.bucket_name
  processed_bucket          = "nyc-taxi-processed-dev-yenugula"
}

module "raw_bucket" {
  source      = "../../modules/s3"
  bucket_name = "nyc-taxi-raw-dev-yenugula"
}

module "processed_bucket" {
  source      = "../../modules/s3"
  bucket_name = "nyc-taxi-processed-dev-yenugula"
}

module "glue" {
  source           = "../../modules/glue"
  project          = "nyc-taxi"
  environment      = var.environment
  raw_bucket       = module.raw_bucket.bucket_name
  processed_bucket = module.processed_bucket.bucket_name
  scripts_bucket   = "nyc-taxi-${var.environment}-glue-scripts"
}

module "monitoring" {
  source           = "../../modules/monitoring"
  project          = "nyc-taxi"
  environment      = var.environment
  alert_email      = var.alert_email
  rds_instance_id  = "nyc-taxi-dev-mlflow-db"
  eks_cluster_name = "nyc-taxi-dev-cluster"
}

module "efs" {
  source                     = "../../modules/efs"
  project                    = "nyc-taxi"
  environment                = var.environment
  vpc_id                     = module.vpc.vpc_id
  private_subnet_ids         = module.vpc.private_subnet_ids
  eks_node_security_group_id = module.eks.node_security_group_id
}