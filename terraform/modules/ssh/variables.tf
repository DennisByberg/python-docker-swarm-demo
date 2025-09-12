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

variable "key_size" {
  description = "Size of the RSA key in bits"
  type        = number
  default     = 4096
}

variable "private_key_path" {
  description = "Path where the private key will be saved"
  type        = string
  default     = "~/.ssh/docker-swarm-key.pem"
}