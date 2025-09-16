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

variable "ami_id" {
  description = "AMI ID for EC2 instances"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Name of the AWS key pair for SSH access"
  type        = string
}

variable "security_group_id" {
  description = "ID of the security group for instances"
  type        = string
}

variable "instance_profile_name" {
  description = "Name of the IAM instance profile"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for Auto Scaling Group"
  type        = list(string)
}

variable "target_group_arns" {
  description = "Map of target group ARNs for load balancer attachment"
  type = object({
    nginx      = string
    visualizer = string
    fastapi    = string
  })
}

variable "min_workers" {
  description = "Minimum number of worker instances"
  type        = number
  default     = 2
}

variable "max_workers" {
  description = "Maximum number of worker instances"
  type        = number
  default     = 6
}

variable "desired_workers" {
  description = "Desired number of worker instances"
  type        = number
  default     = 2
}

variable "aws_region" {
  description = "AWS region for user data template"
  type        = string
}

variable "manager_user_data_file" {
  description = "Path to manager initialization script"
  type        = string
  default     = "../scripts/ec2/manager-init.sh"
}

variable "worker_user_data_file" {
  description = "Path to worker initialization script"
  type        = string
  default     = "../scripts/ec2/worker-init-asg.sh"
}

variable "cpu_scale_up_threshold" {
  description = "CPU utilization threshold for scaling up"
  type        = number
  default     = 50
}

variable "cpu_scale_down_threshold" {
  description = "CPU utilization threshold for scaling down"
  type        = number
  default     = 20
}