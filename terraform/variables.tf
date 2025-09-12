variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "eu-north-1"
}

variable "instance_type" {
  description = "EC2 instance type for all nodes"
  type        = string
  default     = "t3.micro"
}

variable "ami_id" {
  description = "AMI ID for EC2 instances"
  type        = string
  default     = "ami-0c4fc5dcabc9df21d" # Amazon Linux 2 in eu-north-1
}

variable "worker_count" {
  description = "Initial number of worker nodes"
  type        = number
  default     = 2

  validation {
    condition     = var.worker_count >= 1 && var.worker_count <= 10
    error_message = "Worker count must be between 1 and 10."
  }
}

variable "min_workers" {
  description = "Minimum number of workers in Auto Scaling Group"
  type        = number
  default     = 2

  validation {
    condition     = var.min_workers >= 1
    error_message = "Minimum workers must be at least 1."
  }
}

variable "max_workers" {
  description = "Maximum number of workers in Auto Scaling Group"
  type        = number
  default     = 6

  validation {
    condition     = var.max_workers <= 20
    error_message = "Maximum workers cannot exceed 20."
  }
}

# Project Configuration
variable "project_name" {
  description = "Name of the project for resource naming"
  type        = string
  default     = "docker-swarm"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "demo"

  validation {
    condition     = contains(["dev", "staging", "prod", "demo"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod, demo."
  }
}

# Security Configuration
variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the services"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# Auto Scaling Configuration
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