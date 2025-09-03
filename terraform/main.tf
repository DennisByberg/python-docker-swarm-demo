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

# EC2 Instances
resource "aws_instance" "manager" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.docker_swarm_key.key_name
  vpc_security_group_ids = [aws_security_group.docker_swarm.id]
  user_data              = file("../scripts/manager-init.sh")

  tags = {
    Name = "swarm-manager"
  }
}

resource "aws_instance" "workers" {
  count                  = var.worker_count
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.docker_swarm_key.key_name
  vpc_security_group_ids = [aws_security_group.docker_swarm.id]
  depends_on             = [aws_instance.manager]

  user_data = templatefile("../scripts/worker-init.sh", {
    manager_private_ip = aws_instance.manager.private_ip
  })

  tags = {
    Name = "swarm-worker-${count.index + 1}"
  }
}