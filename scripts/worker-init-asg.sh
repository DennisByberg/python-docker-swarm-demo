#!/bin/bash

# Docker Swarm Worker Node Initialization Script
# This script is executed on worker nodes created by Auto Scaling Group

# Install and configure Docker
dnf update -y
dnf install -y docker
systemctl start docker
systemctl enable docker
usermod -aG docker ec2-user

# Install AWS CLI v2 for ECR access and SSM parameter retrieval
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

sleep 10

# Configure AWS region from Terraform variable
export AWS_DEFAULT_REGION=${aws_region}

# Get AWS account ID for ECR repository URL
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Login to ECR to enable pulling Docker images on this worker node
aws ecr get-login-password \
    --region ${aws_region} | docker login \
    --username AWS \
    --password-stdin $ACCOUNT_ID.dkr.ecr.${aws_region}.amazonaws.com

# Wait for manager node to store the worker join token in SSM
for i in {1..30}; do
    TOKEN=$(aws ssm get-parameter --name "/docker-swarm/worker-token" --region ${aws_region} --query 'Parameter.Value' --output text 2>/dev/null)
    if [ ! -z "$TOKEN" ] && [ "$TOKEN" != "None" ]; then
        break
    fi
    sleep 30
done

# Exit with error if token retrieval failed after all attempts
if [ -z "$TOKEN" ] || [ "$TOKEN" == "None" ]; then
    exit 1
fi

# Join the Docker Swarm cluster as a worker node
docker swarm join --token $TOKEN ${manager_private_ip}:2377