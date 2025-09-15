# Terraform and AWS Provider Configuration
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

# AWS Provider configuration
provider "aws" {
  region = var.aws_region
}

# Get current AWS account information for IAM policies
data "aws_caller_identity" "current" {}

# SSH key generation and management for EC2 access
module "ssh" {
  source = "./modules/ssh"
}

# VPC, security groups, and Application Load Balancer setup
module "networking" {
  source = "./modules/networking"
}

# S3 bucket for images and DynamoDB table for posts
module "storage" {
  source = "./modules/storage"
}

# IAM roles and policies for EC2 instances
module "iam" {
  source = "./modules/iam"

  aws_region         = var.aws_region
  aws_account_id     = data.aws_caller_identity.current.account_id
  s3_bucket_arn      = module.storage.s3_bucket_arn
  dynamodb_table_arn = module.storage.dynamodb_table_arn
}

# Docker Swarm cluster with manager and Auto Scaling workers
module "compute" {
  source = "./modules/compute"

  ami_id                = var.ami_id
  instance_type         = var.instance_type
  key_name              = module.ssh.key_name
  security_group_id     = module.networking.security_group_id
  instance_profile_name = module.iam.instance_profile_name
  subnet_ids            = module.networking.subnet_ids
  target_group_arns     = module.networking.target_group_arns
  desired_workers       = var.worker_count
  aws_region            = var.aws_region
}