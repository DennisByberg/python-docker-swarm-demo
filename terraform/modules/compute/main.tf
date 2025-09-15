# EC2 Manager Instance
resource "aws_instance" "manager" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [var.security_group_id]
  iam_instance_profile   = var.instance_profile_name
  user_data              = file(var.manager_user_data_file)

  tags = {
    Name        = "${var.project_name}-manager"
    Environment = var.environment
    Role        = "swarm-manager"
  }
}

# Target Group Attachments for Manager
resource "aws_lb_target_group_attachment" "manager_nginx" {
  target_group_arn = var.target_group_arns.nginx
  target_id        = aws_instance.manager.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "manager_visualizer" {
  target_group_arn = var.target_group_arns.visualizer
  target_id        = aws_instance.manager.id
  port             = 8080
}

resource "aws_lb_target_group_attachment" "manager_fastapi" {
  target_group_arn = var.target_group_arns.fastapi
  target_id        = aws_instance.manager.id
  port             = 8001
}

# Launch Template for Worker Instances
resource "aws_launch_template" "worker_template" {
  name_prefix   = "${var.project_name}-worker-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  vpc_security_group_ids = [var.security_group_id]

  iam_instance_profile {
    name = var.instance_profile_name
  }

  # Template user data with manager IP and region
  user_data = base64encode(templatefile(var.worker_user_data_file, {
    manager_private_ip = aws_instance.manager.private_ip
    aws_region         = var.aws_region
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.project_name}-worker-asg"
      Environment = var.environment
      Role        = "swarm-worker"
    }
  }

  tags = {
    Name        = "${var.project_name}-worker-template"
    Environment = var.environment
  }
}

# Auto Scaling Group for Worker Instances
resource "aws_autoscaling_group" "worker_asg" {
  name                = "${var.project_name}-workers"
  vpc_zone_identifier = var.subnet_ids

  # Attach to load balancer target groups
  target_group_arns = [
    var.target_group_arns.nginx,
    var.target_group_arns.fastapi
  ]

  health_check_type         = "ELB"
  health_check_grace_period = 300

  min_size         = var.min_workers
  max_size         = var.max_workers
  desired_capacity = var.desired_workers

  launch_template {
    id      = aws_launch_template.worker_template.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-worker-asg"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  tag {
    key                 = "Role"
    value               = "swarm-worker"
    propagate_at_launch = true
  }
}

# Auto Scaling Policy - Scale Up
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "${var.project_name}-scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.worker_asg.name
}

# Auto Scaling Policy - Scale Down
resource "aws_autoscaling_policy" "scale_down" {
  name                   = "${var.project_name}-scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.worker_asg.name
}

# CloudWatch Alarm - High CPU Utilization
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.project_name}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = var.cpu_scale_up_threshold
  alarm_description   = "This metric monitors EC2 CPU utilization for scale up"
  alarm_actions       = [aws_autoscaling_policy.scale_up.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.worker_asg.name
  }

  tags = {
    Name        = "${var.project_name}-cpu-high-alarm"
    Environment = var.environment
  }
}

# CloudWatch Alarm - Low CPU Utilization
resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "${var.project_name}-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = var.cpu_scale_down_threshold
  alarm_description   = "This metric monitors EC2 CPU utilization for scale down"
  alarm_actions       = [aws_autoscaling_policy.scale_down.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.worker_asg.name
  }

  tags = {
    Name        = "${var.project_name}-cpu-low-alarm"
    Environment = var.environment
  }
}