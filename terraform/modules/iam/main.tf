# IAM Role for Docker Swarm instances
resource "aws_iam_role" "docker_swarm_role" {
  name = "${var.project_name}-ecr-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-role"
    Environment = var.environment
  }
}

# IAM Policy for ECR and SSM access
resource "aws_iam_role_policy" "docker_swarm_ecr_policy" {
  name = "${var.project_name}-ecr-policy"
  role = aws_iam_role.docker_swarm_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:PutParameter",
          "ssm:GetParameter",
          "ssm:DeleteParameter"
        ]
        Resource = "arn:aws:ssm:${var.aws_region}:${var.aws_account_id}:parameter/docker-swarm/*"
      },
      {
        Effect = "Allow"
        Action = [
          "sts:GetCallerIdentity"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM Policy for S3 and DynamoDB access
resource "aws_iam_policy" "s3_dynamodb_access" {
  name        = "${var.project_name}-S3DynamoDBAccess"
  description = "IAM policy for S3 and DynamoDB access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:HeadBucket"
        ]
        Resource = [
          var.s3_bucket_arn,
          "${var.s3_bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:DescribeTable"
        ]
        Resource = var.dynamodb_table_arn
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-s3-dynamodb-policy"
    Environment = var.environment
  }
}

# Attach S3/DynamoDB policy to role
resource "aws_iam_role_policy_attachment" "s3_dynamodb_policy" {
  role       = aws_iam_role.docker_swarm_role.name
  policy_arn = aws_iam_policy.s3_dynamodb_access.arn
}

# Instance Profile
resource "aws_iam_instance_profile" "docker_swarm_profile" {
  name = "${var.project_name}-profile"
  role = aws_iam_role.docker_swarm_role.name

  tags = {
    Name        = "${var.project_name}-instance-profile"
    Environment = var.environment
  }
}