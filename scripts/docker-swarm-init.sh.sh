#!/bin/bash

# Update system
dnf update -y

# Install Docker
dnf install -y docker

# Start and enable Docker
systemctl enable docker
systemctl start docker

# Add ec2-user to docker group
usermod -aG docker ec2-user

# Install AWS CLI v2 (för ECR)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

# Create directory for docker logs
mkdir -p /var/log/docker-init

# Log successful installation
echo "$(date): Docker installed successfully on ${node_type} node" >> /var/log/docker-init/install.log

# Wait for Docker to be ready
sleep 30

# Test Docker installation
docker --version >> /var/log/docker-init/install.log 2>&1