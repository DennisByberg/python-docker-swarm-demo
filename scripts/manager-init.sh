#!/bin/bash

set -e

# Update system and install Docker (using DNF for Amazon Linux 2023)
dnf update -y
dnf install -y docker jq

# Start Docker service
systemctl start docker
systemctl enable docker

# Add ec2-user to docker group
usermod -a -G docker ec2-user

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Wait for Docker to be ready
sleep 30

# Initialize Docker Swarm (using your robust IP detection)
MANAGER_IP=$(hostname -I | awk '{print $1}')
docker swarm init --advertise-addr $MANAGER_IP

# Get join token and save to EC2 Parameter Store
WORKER_TOKEN=$(docker swarm join-token worker -q)
aws ssm put-parameter \
    --name "/docker-swarm/worker-token" \
    --value "$WORKER_TOKEN" \
    --type "String" \
    --overwrite \
    --region eu-north-1

# Login to ECR automatically
AWS_REGION=eu-north-1
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

# Deploy initial services
cat > /home/ec2-user/myapp-stack.yml << 'EOF'
version: "3.8"

services:
  web:
    image: nginx:stable-alpine
    ports:
      - "80:80"
    deploy:
      replicas: 3
      restart_policy:
        condition: on-failure
    networks:
      - app-network

  viz:
    image: dockersamples/visualizer:stable
    ports:
      - "8080:8080"
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock"
    deploy:
      placement:
        constraints:
          - node.role == manager
    networks:
      - app-network

networks:
  app-network:
    driver: overlay
EOF

chown ec2-user:ec2-user /home/ec2-user/myapp-stack.yml

# Wait a bit more for everything to settle, then deploy
sleep 60
docker stack deploy -c /home/ec2-user/myapp-stack.yml myapp

echo "Manager node setup completed with IP: $MANAGER_IP"