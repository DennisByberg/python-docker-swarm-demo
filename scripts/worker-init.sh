#!/bin/bash

set -e

# Update system and install Docker (using DNF)
dnf update -y
dnf install -y docker jq

# Start Docker service
systemctl start docker
systemctl enable docker

# Add ec2-user to docker group
usermod -a -G docker ec2-user

# Wait for manager to be ready and get join token
sleep 90
WORKER_TOKEN=$(aws ssm get-parameter --name "/docker-swarm/worker-token" --region ${aws_region} --query 'Parameter.Value' --output text)

# Join the swarm
docker swarm join --token $WORKER_TOKEN ${manager_private_ip}:2377

# Login to ECR automatically
AWS_REGION=${aws_region}
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $${ACCOUNT_ID}.dkr.ecr.$${AWS_REGION}.amazonaws.com

echo "Worker node setup completed"