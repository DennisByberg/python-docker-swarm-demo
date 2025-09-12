# Terraform and AWS Provider
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
provider "aws" {
  region = var.aws_region
}

# Networking Module
module "networking" {
  source = "./modules/networking"

  project_name        = "docker-swarm"
  environment         = "demo"
  allowed_cidr_blocks = ["0.0.0.0/0"]
}

# SSH Key
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "docker_swarm_key" {
  key_name   = "docker-swarm-key"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

resource "local_file" "private_key" {
  content         = tls_private_key.ssh_key.private_key_pem
  filename        = pathexpand("~/.ssh/docker-swarm-key.pem")
  file_permission = "0400"
}

# IAM Role and Instance Profile
resource "aws_iam_role" "docker_swarm_role" {
  name = "docker-swarm-ecr-role"

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
}

# IAM Policy
resource "aws_iam_role_policy" "docker_swarm_ecr_policy" {
  name = "docker-swarm-ecr-policy"
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
        Resource = "arn:aws:ssm:*:*:parameter/docker-swarm/*"
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

# Instance Profile
resource "aws_iam_instance_profile" "docker_swarm_profile" {
  name = "docker-swarm-profile"
  role = aws_iam_role.docker_swarm_role.name
}

# EC2 Manager Instance
resource "aws_instance" "manager" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.docker_swarm_key.key_name
  vpc_security_group_ids = [module.networking.security_group_id]
  iam_instance_profile   = aws_iam_instance_profile.docker_swarm_profile.name
  user_data              = file("../scripts/manager-init.sh")

  tags = {
    Name = "swarm-manager"
  }
}

# Target Group Attachments for Manager
resource "aws_lb_target_group_attachment" "manager_nginx" {
  target_group_arn = module.networking.target_group_arns.nginx
  target_id        = aws_instance.manager.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "manager_visualizer" {
  target_group_arn = module.networking.target_group_arns.visualizer
  target_id        = aws_instance.manager.id
  port             = 8080
}

resource "aws_lb_target_group_attachment" "manager_fastapi" {
  target_group_arn = module.networking.target_group_arns.fastapi
  target_id        = aws_instance.manager.id
  port             = 8001
}

# Auto Scaling Group för workers
resource "aws_launch_template" "worker_template" {
  name_prefix   = "docker-swarm-worker-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = aws_key_pair.docker_swarm_key.key_name

  vpc_security_group_ids = [module.networking.security_group_id]

  iam_instance_profile {
    name = aws_iam_instance_profile.docker_swarm_profile.name
  }

  user_data = base64encode(templatefile("../scripts/worker-init-asg.sh", {
    manager_private_ip = aws_instance.manager.private_ip
    aws_region         = var.aws_region
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "swarm-worker-asg"
    }
  }
}

resource "aws_autoscaling_group" "worker_asg" {
  name                = "docker-swarm-workers"
  vpc_zone_identifier = module.networking.subnet_ids

  target_group_arns = [
    module.networking.target_group_arns.nginx,
    module.networking.target_group_arns.fastapi
  ]

  health_check_type         = "ELB"
  health_check_grace_period = 300

  min_size         = var.min_workers
  max_size         = var.max_workers
  desired_capacity = var.worker_count

  launch_template {
    id      = aws_launch_template.worker_template.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "swarm-worker-asg"
    propagate_at_launch = true
  }
}

# Auto Scaling Policies
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "docker-swarm-scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.worker_asg.name
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "docker-swarm-scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.worker_asg.name
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "docker-swarm-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "50"
  alarm_description   = "This metric monitors ec2 cpu utilization"
  alarm_actions       = [aws_autoscaling_policy.scale_up.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.worker_asg.name
  }
}

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "docker-swarm-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "20"
  alarm_description   = "This metric monitors ec2 cpu utilization"
  alarm_actions       = [aws_autoscaling_policy.scale_down.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.worker_asg.name
  }
}

# S3 Bucket för image storage
resource "aws_s3_bucket" "image_uploads" {
  bucket = "fastapi-upload-demo-${random_string.bucket_suffix.result}"
}

resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket_versioning" "image_uploads" {
  bucket = aws_s3_bucket.image_uploads.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "image_uploads" {
  bucket = aws_s3_bucket.image_uploads.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "image_uploads" {
  bucket = aws_s3_bucket.image_uploads.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB Table för posts
resource "aws_dynamodb_table" "posts" {
  name         = "fastapi-upload-posts"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = {
    Name        = "FastAPI Upload Posts"
    Environment = "demo"
  }
}

# IAM Policy för S3 och DynamoDB access
resource "aws_iam_policy" "s3_dynamodb_access" {
  name        = "S3DynamoDBAccess"
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
          "${aws_s3_bucket.image_uploads.arn}",
          "${aws_s3_bucket.image_uploads.arn}/*"
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
        Resource = aws_dynamodb_table.posts.arn
      }
    ]
  })
}

# Attach policy to existing role
resource "aws_iam_role_policy_attachment" "s3_dynamodb_policy" {
  role       = aws_iam_role.docker_swarm_role.name
  policy_arn = aws_iam_policy.s3_dynamodb_access.arn
}