variable "project_name" {
  description = "Name of the project for resource naming"
  type        = string
  default     = "docker-swarm"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket for IAM policies"
  type        = string
}

variable "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table for IAM policies"
  type        = string
}

variable "aws_region" {
  description = "AWS region for SSM parameter access"
  type        = string
}

variable "aws_account_id" {
  description = "AWS Account ID for resource ARNs"
  type        = string
}