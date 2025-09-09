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

# Default VPC
data "aws_vpc" "default" {
  default = true
}

# Data source to get subnets in the default VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Security Group
resource "aws_security_group" "docker_swarm" {
  name_prefix = "docker-swarm-"
  description = "Security group for Docker Swarm"

  # Essential ports only
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Docker Swarm cluster communication
  ingress {
    from_port = 2377
    to_port   = 2377
    protocol  = "tcp"
    self      = true
  }

  ingress {
    from_port = 7946
    to_port   = 7946
    protocol  = "tcp"
    self      = true
  }

  ingress {
    from_port = 7946
    to_port   = 7946
    protocol  = "udp"
    self      = true
  }

  ingress {
    from_port = 4789
    to_port   = 4789
    protocol  = "udp"
    self      = true
  }

  # Token server
  ingress {
    from_port = 8000
    to_port   = 8000
    protocol  = "tcp"
    self      = true
  }

  # FastAPI app port
  # This is needed if you want to access the app directly on the nodes
  ingress {
    from_port   = 8001
    to_port     = 8001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
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
# -------------------------------
# Creates an identity that EC2 instances can "assume" to get AWS permissions
# assume_role_policy: Says that only the EC2 service can use this role
# This is the foundation for giving our Docker Swarm nodes access to AWS services
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
# -----------
# Defines which AWS services our EC2 instances are allowed to use
# ECR: Pull Docker images from AWS Container Registry
# SSM: Store/retrieve Docker Swarm join-tokens securely between nodes
# STS: Get AWS account-ID to build ECR repository URLs
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
# ----------------
# Makes it possible for EC2 instances to use the IAM role
# EC2 instances cannot directly use IAM roles, they need an Instance Profile as a "wrapper"
# This gives our Docker Swarm nodes access to ECR and SSM via temporary credentials
# Used to pull Docker images from ECR and store/retrieve tokens in SSM Parameter Store
resource "aws_iam_instance_profile" "docker_swarm_profile" {
  name = "docker-swarm-profile"
  role = aws_iam_role.docker_swarm_role.name
}

# EC2 Manager Instance
resource "aws_instance" "manager" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.docker_swarm_key.key_name
  vpc_security_group_ids = [aws_security_group.docker_swarm.id]
  iam_instance_profile   = aws_iam_instance_profile.docker_swarm_profile.name
  user_data              = file("../scripts/manager-init.sh")

  tags = {
    Name = "swarm-manager"
  }
}

# Application Load Balancer
resource "aws_lb" "docker_swarm_alb" {
  name               = "docker-swarm-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = data.aws_subnets.default.ids

  enable_deletion_protection = false
}

# ALB Security Group
resource "aws_security_group" "alb_sg" {
  name_prefix = "docker-swarm-alb-"
  description = "Security group for Docker Swarm ALB"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Lägg till denna för FastAPI
  ingress {
    from_port   = 8001
    to_port     = 8001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Target Group for FastAPI app
resource "aws_lb_target_group" "fastapi" {
  name     = "docker-swarm-fastapi"
  port     = 8001
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name = "docker-swarm-fastapi"
  }
}

# Target Group for Visualizer
resource "aws_lb_target_group" "visualizer" {
  name     = "docker-swarm-visualizer"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name = "docker-swarm-visualizer"
  }
}

# Target Group for Nginx
resource "aws_lb_target_group" "nginx" {
  name     = "docker-swarm-nginx"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name = "docker-swarm-nginx"
  }
}

# ALB Listener for HTTP
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.docker_swarm_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nginx.arn
  }
}

# ALB Listener for Visualizer
resource "aws_lb_listener" "visualizer" {
  load_balancer_arn = aws_lb.docker_swarm_alb.arn
  port              = "8080"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.visualizer.arn
  }
}

# ALB Listener for FastAPI
resource "aws_lb_listener" "fastapi" {
  load_balancer_arn = aws_lb.docker_swarm_alb.arn
  port              = "8001"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.fastapi.arn
  }
}

# Target Group Attachments for Manager
resource "aws_lb_target_group_attachment" "manager_nginx" {
  target_group_arn = aws_lb_target_group.nginx.arn
  target_id        = aws_instance.manager.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "manager_visualizer" {
  target_group_arn = aws_lb_target_group.visualizer.arn
  target_id        = aws_instance.manager.id
  port             = 8080
}

resource "aws_lb_target_group_attachment" "manager_fastapi" {
  target_group_arn = aws_lb_target_group.fastapi.arn
  target_id        = aws_instance.manager.id
  port             = 8001
}

# Auto Scaling Group för workers
resource "aws_launch_template" "worker_template" {
  name_prefix   = "docker-swarm-worker-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = aws_key_pair.docker_swarm_key.key_name

  vpc_security_group_ids = [aws_security_group.docker_swarm.id]

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
  vpc_zone_identifier = data.aws_subnets.default.ids

  target_group_arns = [
    aws_lb_target_group.nginx.arn,
    aws_lb_target_group.fastapi.arn
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