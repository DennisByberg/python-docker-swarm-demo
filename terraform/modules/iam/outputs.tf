output "role_arn" {
  description = "ARN of the Docker Swarm IAM role"
  value       = aws_iam_role.docker_swarm_role.arn
}

output "role_name" {
  description = "Name of the Docker Swarm IAM role"
  value       = aws_iam_role.docker_swarm_role.name
}

output "instance_profile_name" {
  description = "Name of the IAM instance profile"
  value       = aws_iam_instance_profile.docker_swarm_profile.name
}

output "instance_profile_arn" {
  description = "ARN of the IAM instance profile"
  value       = aws_iam_instance_profile.docker_swarm_profile.arn
}

output "s3_dynamodb_policy_arn" {
  description = "ARN of the S3/DynamoDB access policy"
  value       = aws_iam_policy.s3_dynamodb_access.arn
}