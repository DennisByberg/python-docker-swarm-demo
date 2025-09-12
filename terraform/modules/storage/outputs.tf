output "s3_bucket_id" {
  description = "ID of the S3 bucket for image storage"
  value       = aws_s3_bucket.image_uploads.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket for image storage"
  value       = aws_s3_bucket.image_uploads.arn
}

output "s3_bucket_domain_name" {
  description = "Domain name of the S3 bucket"
  value       = aws_s3_bucket.image_uploads.bucket_domain_name
}

output "s3_bucket_regional_domain_name" {
  description = "Regional domain name of the S3 bucket"
  value       = aws_s3_bucket.image_uploads.bucket_regional_domain_name
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table for posts"
  value       = aws_dynamodb_table.posts.name
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table for posts"
  value       = aws_dynamodb_table.posts.arn
}

output "dynamodb_table_id" {
  description = "ID of the DynamoDB table for posts"
  value       = aws_dynamodb_table.posts.id
}