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

variable "bucket_suffix_length" {
  description = "Length of random suffix for S3 bucket name"
  type        = number
  default     = 8
}

variable "enable_s3_versioning" {
  description = "Enable versioning for S3 bucket"
  type        = bool
  default     = true
}

variable "dynamodb_billing_mode" {
  description = "Billing mode for DynamoDB table"
  type        = string
  default     = "PAY_PER_REQUEST"
}