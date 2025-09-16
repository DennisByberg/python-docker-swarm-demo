#!/bin/bash

set -e
source "$(dirname "$0")/utils.sh"

AWS_REGION="eu-north-1"
REPO_NAME="fastapi-upload-demo"

# Auto-increment image tag if not provided
if [ -z "$IMAGE_TAG" ]; then
    echo -n "Finding next version tag..."
    
    # Run AWS command without background process to avoid variable scope issues
    LATEST_TAG=$(aws ecr describe-images \
        --repository-name $REPO_NAME \
        --region $AWS_REGION \
        --query 'imageDetails[].imageTags[]' \
        --output text 2>/dev/null | \
        tr '\t' '\n' | \
        grep -E '^v[0-9]+$' | \
        sed 's/v//' | \
        sort -n | \
        tail -1)
    
    sleep 1
    echo "   "
    
    if [ -z "$LATEST_TAG" ]; then
        IMAGE_TAG="v1"
        echo "No previous tags found, using v1"
    else
        NEXT_VERSION=$((LATEST_TAG + 1))
        IMAGE_TAG="v${NEXT_VERSION}"
        echo "Found v${LATEST_TAG}, using v${NEXT_VERSION}"
    fi
fi

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

# Export IMAGE_TAG so build script can use it
export IMAGE_TAG

# Build and push to ECR
echo -n "Building and pushing FastAPI (tag: $IMAGE_TAG)..."
(./build-push-fastapi.sh) >/dev/null 2>&1 &
spinner

# Get infrastructure info
cd ../../terraform
MANAGER_IP=$(terraform output -raw manager_public_ip 2>/dev/null)
if [ -z "$MANAGER_IP" ]; then
    echo "❌ Error: No manager IP found. Run terraform apply first!"
    exit 1
fi

WORKER_IPS_JSON=$(terraform output -json worker_public_ips)
WORKER_IPS=$(echo "$WORKER_IPS_JSON" | grep -o '"[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*"' | tr -d '"' | tr '\n' ' ')

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
IMAGE_URI="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPO_NAME}:${IMAGE_TAG}"

# Login manager to ECR and pull image
echo -n "Logging manager into ECR..."
(
    ssh -o StrictHostKeyChecking=no -i ~/.ssh/docker-swarm-key.pem ec2-user@$MANAGER_IP "
        aws ecr get-login-password --region $AWS_REGION | \
        docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com && \
        docker pull ${IMAGE_URI}
    "
) >/dev/null 2>&1 &
spinner

# Login workers to ECR and pull image
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

cd ../scripts/local

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