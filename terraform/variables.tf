variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-north-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "worker_count" {
  description = "Initial number of worker nodes"
  type        = number
  default     = 2
}

variable "ami_id" {
  description = "AMI ID for EC2 instances"
  type        = string
  default     = "ami-0c4fc5dcabc9df21d" # Amazon Linux 2 in eu-north-1
}

variable "min_workers" {
  description = "Minimum number of workers in Auto Scaling Group"
  type        = number
  default     = 2
}

variable "max_workers" {
  description = "Maximum number of workers in Auto Scaling Group"
  type        = number
  default     = 6
}