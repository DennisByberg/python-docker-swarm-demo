#!/bin/bash

set -e
source "$(dirname "$0")/utils.sh"

# Configuration variables
AWS_REGION="eu-north-1"
REPO_NAME="fastapi-upload-demo"
IMAGE_TAG="v1"
STACK_NAME="myapp"
SSH_KEY_PATH="~/.ssh/docker-swarm-key.pem"

# Deploy infrastructure
(cd ../terraform && terraform apply -auto-approve) >/dev/null 2>&1 &
spinner $! "Deploying infrastructure with ALB + ASG..."

# Get outputs from Terraform
cd ../terraform
MANAGER_IP=$(terraform output -raw manager_public_ip)
ALB_DNS=$(terraform output -raw load_balancer_dns)
ASG_NAME=$(terraform output -raw autoscaling_group_name)

# Wait for Docker Swarm to initialize
(sleep 120) &
spinner $! "Waiting for Docker Swarm to initialize..."

# Create ECR repository if needed
(
    if ! aws ecr describe-repositories \
        --repository-names ${REPO_NAME} \
        --region ${AWS_REGION} \
        >/dev/null 2>&1; then
        
        aws ecr create-repository \
            --repository-name ${REPO_NAME} \
            --region ${AWS_REGION} \
            --image-scanning-configuration scanOnPush=true \
            --encryption-configuration encryptionType=AES256 \
            >/dev/null 2>&1
    fi
) &
spinner $! "Ensuring ECR repository exists..."

# Build and push FastAPI app locally first
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
IMAGE_URI="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPO_NAME}:${IMAGE_TAG}"

(
    cd ../app
    docker build -t ${REPO_NAME}:${IMAGE_TAG} -t ${IMAGE_URI} .
) >/dev/null 2>&1 &
spinner $! "Building FastAPI image locally..."

(
    aws ecr get-login-password --region ${AWS_REGION} | \
    docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
    
    docker push ${IMAGE_URI}
) >/dev/null 2>&1 &
spinner $! "Pushing FastAPI image to ECR..."

# Deploy basic stack to Swarm manager
(
    ssh -o StrictHostKeyChecking=no -i ${SSH_KEY_PATH} ec2-user@${MANAGER_IP} "
        aws ecr get-login-password --region ${AWS_REGION} | \
        docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
        
        docker pull ${IMAGE_URI}

        cat > basic-stack.yml << 'STACKEOF'
version: \"3.8\"

services:
  nginx:
    image: nginx:stable-alpine
    deploy:
      replicas: 3
      placement:
        max_replicas_per_node: 1
      restart_policy:
        condition: on-failure
    ports:
      - \"80:80\"
    networks:
      - app-network

  visualizer:
    image: dockersamples/visualizer:stable
    ports:
      - \"8080:8080\"
    volumes:
      - \"/var/run/docker.sock:/var/run/docker.sock\"
    deploy:
      placement:
        constraints: [node.role == manager]
      restart_policy:
        condition: on-failure
    networks:
      - app-network

networks:
  app-network:
    driver: overlay
STACKEOF

        docker stack deploy -c basic-stack.yml ${STACK_NAME}
        sleep 30
    "
) >/dev/null 2>&1 &
spinner $! "Deploying basic stack to Docker Swarm..."

# Deploy FastAPI service globally
(
    ssh -o StrictHostKeyChecking=no -i ${SSH_KEY_PATH} ec2-user@${MANAGER_IP} "
        docker service create \
            --name ${STACK_NAME}_fastapi-app \
            --mode global \
            --publish 8001:8000 \
            --network ${STACK_NAME}_app-network \
            --with-registry-auth \
            ${IMAGE_URI} >/dev/null 2>&1
        
        for i in {1..60}; do
            if [ \$(docker service ls --filter name=${STACK_NAME}_fastapi-app --format '{{.Replicas}}' | cut -d'/' -f1) = '3' ]; then
                break
            fi
            sleep 1
        done
    "
) &
spinner $! "Deploying FastAPI service globally..."

# Wait for Load Balancer health checks
(sleep 120) &
spinner $! "Waiting for Load Balancer health checks to pass..."

# Test endpoints via Load Balancer
(
    for i in {1..20}; do
        if curl -s "http://${ALB_DNS}:8001/health" >/dev/null 2>&1; then
            break
        fi
        sleep 15
    done
) &
spinner $! "Testing endpoints via Load Balancer..."

echo "Nginx:          http://${ALB_DNS}"
echo "Visualizer:     http://${ALB_DNS}:8080"  
echo "FastAPI:        http://${ALB_DNS}:8001"
echo "SSH to manager: ssh -i ${SSH_KEY_PATH} ec2-user@${MANAGER_IP}"

echo "🎉 Deployment completed!"