#!/bin/bash

set -e
source "$(dirname "$0")/utils.sh"

AWS_REGION="eu-north-1"
REPO_NAME="fastapi-upload-demo"
IMAGE_TAG="v1"

# Deploy infrastructure
echo -n "Deploying infrastructure..."
(cd ../terraform && terraform apply -auto-approve) >/dev/null 2>&1 &
spinner

# Get IPs
cd ../terraform
MANAGER_IP=$(terraform output -raw manager_public_ip)
WORKER_IPS_JSON=$(terraform output -json worker_public_ips)
WORKER_IPS=$(echo "$WORKER_IPS_JSON" | grep -o '"[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*"' | tr -d '"' | tr '\n' ' ')

# Wait for Docker Swarm
echo -n "Waiting for Docker Swarm..."
(sleep 120) &
spinner

# Create ECR repository if needed
echo -n "Ensuring ECR repository exists..."
(
    if ! aws ecr describe-repositories \
        --repository-names $REPO_NAME \
        --region $AWS_REGION \
        >/dev/null 2>&1; then
        
        aws ecr create-repository \
            --repository-name $REPO_NAME \
            --region $AWS_REGION \
            --image-scanning-configuration scanOnPush=true \
            --encryption-configuration encryptionType=AES256 \
            >/dev/null 2>&1
    fi
) &
spinner

# Build and push FastAPI app
cd ../scripts
echo -n "Building and pushing FastAPI..."
(./build-push-fastapi.sh) >/dev/null 2>&1 &
spinner

# Setup ECR variables
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
IMAGE_URI="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPO_NAME}:${IMAGE_TAG}"

# Login manager to ECR
echo -n "Logging manager into ECR..."
(
    ssh -o StrictHostKeyChecking=no -i ~/.ssh/docker-swarm-key.pem ec2-user@$MANAGER_IP "
        aws ecr get-login-password --region $AWS_REGION | \
        docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com && \
        docker pull ${IMAGE_URI}
    "
) >/dev/null 2>&1 &
spinner

# Login workers to ECR
echo -n "Logging workers into ECR..."
(
    for WORKER_IP in $WORKER_IPS; do
        ssh -o StrictHostKeyChecking=no -i ~/.ssh/docker-swarm-key.pem ec2-user@$WORKER_IP "
            aws ecr get-login-password --region $AWS_REGION | \
            docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com && \
            docker pull ${IMAGE_URI}
        " >/dev/null 2>&1 || true
    done
) &
spinner

# Deploy to swarm
echo -n "Deploying to Docker Swarm..."
(
    ssh -o StrictHostKeyChecking=no -i ~/.ssh/docker-swarm-key.pem ec2-user@${MANAGER_IP} "
        cat > fastapi-stack.yml << 'STACKEOF'
version: \"3.8\"

services:
  fastapi-app:
    image: ${IMAGE_URI}
    deploy:
      replicas: 3
      restart_policy:
        condition: on-failure
      placement:
        max_replicas_per_node: 1
    ports:
      - \"8001:8000\"
    networks:
      - app-network

networks:
  app-network:
    driver: overlay
STACKEOF

        docker stack deploy -c fastapi-stack.yml fastapi-demo
        sleep 20
    "
) >/dev/null 2>&1 &
spinner

# Test endpoint
echo -n "Testing FastAPI endpoint..."
(
    sleep 30
    curl -s "http://${MANAGER_IP}:8001/health" >/dev/null 2>&1
) &
spinner

echo "Deployment completed! ✅"
echo "🌐 FastAPI: http://${MANAGER_IP}:8001"
echo "📊 Visualizer: http://${MANAGER_IP}:8080"