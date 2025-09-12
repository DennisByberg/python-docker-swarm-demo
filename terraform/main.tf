# Terraform and AWS Provider Configuration
# - Defines which providers and versions to use
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.11.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.1.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5.3"
    }
  }
}

# AWS Provider
# - Sets the AWS region for all resources
provider "aws" {
  region = var.aws_region
}

# Data Sources
# - Gets current AWS account information for IAM policies
data "aws_caller_identity" "current" {}

# SSH Module
# - Generates SSH keys for EC2 access
# - Creates AWS key pair and saves private key locally
module "ssh" {
  source = "./modules/ssh"

  project_name = var.project_name
  environment  = var.environment
}

# Networking Module
# - Sets up VPC, security groups, and Application Load Balancer
# - Creates target groups for nginx, visualizer, and FastAPI services
module "networking" {
  source = "./modules/networking"

  project_name        = var.project_name
  environment         = var.environment
  allowed_cidr_blocks = var.allowed_cidr_blocks
}

# Storage Module  
# - Creates S3 bucket for images and DynamoDB table for posts
module "storage" {
  source = "./modules/storage"

  project_name         = var.project_name
  environment          = var.environment
  bucket_suffix_length = 8
  enable_s3_versioning = true
}

# IAM Module
# - Creates IAM roles and policies for EC2 instances
# - Provides access to ECR, S3, DynamoDB, and SSM
module "iam" {
  source = "./modules/iam"

  project_name       = var.project_name
  environment        = var.environment
  aws_region         = var.aws_region
  aws_account_id     = data.aws_caller_identity.current.account_id
  s3_bucket_arn      = module.storage.s3_bucket_arn
  dynamodb_table_arn = module.storage.dynamodb_table_arn
}

# Compute Module
# - Creates Docker Swarm manager and worker instances
# - Sets up Auto Scaling Group and CloudWatch monitoring
module "compute" {
  source = "./modules/compute"

  project_name             = var.project_name
  environment              = var.environment
  ami_id                   = var.ami_id
  instance_type            = var.instance_type
  key_name                 = module.ssh.key_name
  security_group_id        = module.networking.security_group_id
  instance_profile_name    = module.iam.instance_profile_name
  subnet_ids               = module.networking.subnet_ids
  target_group_arns        = module.networking.target_group_arns
  min_workers              = var.min_workers
  max_workers              = var.max_workers
  desired_workers          = var.worker_count
  aws_region               = var.aws_region
  cpu_scale_up_threshold   = var.cpu_scale_up_threshold
  cpu_scale_down_threshold = var.cpu_scale_down_threshold
}