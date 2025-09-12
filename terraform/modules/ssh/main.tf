# Generate SSH key pair for EC2 access
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = var.key_size
}

# Create AWS key pair from generated public key
resource "aws_key_pair" "docker_swarm_key" {
  key_name   = "${var.project_name}-key"
  public_key = tls_private_key.ssh_key.public_key_openssh

  tags = {
    Name        = "${var.project_name}-ssh-key"
    Environment = var.environment
  }
}

# Save private key to local file for SSH access
resource "local_file" "private_key" {
  content         = tls_private_key.ssh_key.private_key_pem
  filename        = pathexpand(var.private_key_path)
  file_permission = "0400"
}