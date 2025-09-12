# Random suffix for S3 bucket name to ensure uniqueness
resource "random_string" "bucket_suffix" {
  length  = var.bucket_suffix_length
  special = false
  upper   = false
}

# S3 Bucket for image storage
resource "aws_s3_bucket" "image_uploads" {
  bucket = "${var.project_name}-upload-demo-${random_string.bucket_suffix.result}"

  tags = {
    Name        = "${var.project_name}-image-uploads"
    Environment = var.environment
    Purpose     = "FastAPI image storage"
  }
}

# S3 Bucket versioning configuration
resource "aws_s3_bucket_versioning" "image_uploads" {
  bucket = aws_s3_bucket.image_uploads.id

  versioning_configuration {
    status = var.enable_s3_versioning ? "Enabled" : "Disabled"
  }
}

# S3 Bucket server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "image_uploads" {
  bucket = aws_s3_bucket.image_uploads.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# S3 Bucket public access block - security best practice
resource "aws_s3_bucket_public_access_block" "image_uploads" {
  bucket = aws_s3_bucket.image_uploads.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB Table for posts
resource "aws_dynamodb_table" "posts" {
  name         = "${var.project_name}-upload-posts"
  billing_mode = var.dynamodb_billing_mode
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  # Enable point-in-time recovery for data protection
  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name        = "${var.project_name} Upload Posts"
    Environment = var.environment
    Purpose     = "FastAPI post storage"
  }
}