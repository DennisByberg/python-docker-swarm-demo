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

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the services"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}