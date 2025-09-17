#!/bin/bash

set -e
source "$(dirname "$0")/utils.sh"

# Configuration
AWS_REGION="eu-north-1"
REPO_NAME="fastapi-upload-demo"
SSH_KEY_PATH="~/.ssh/docker-swarm-key.pem"

# Auto-increment image tag if not provided
determine_image_tag() {
    if [ -z "$IMAGE_TAG" ]; then
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
        
        if [ -z "$LATEST_TAG" ]; then
            IMAGE_TAG="v1"
        else
            NEXT_VERSION=$((LATEST_TAG + 1))
            IMAGE_TAG="v${NEXT_VERSION}"
        fi
        
        export IMAGE_TAG
    fi
}

# Create ECR repository if needed
ensure_ecr_repository() {
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
}

# Build and push FastAPI image
build_and_push_fastapi() {
    ./build-push-fastapi.sh
}

# Get infrastructure information from Terraform
get_infrastructure_info() {
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
    
    cd ../scripts/local
}

# Login manager node to ECR and pull image
setup_manager_node() {
    ssh -o StrictHostKeyChecking=no -i $SSH_KEY_PATH ec2-user@$MANAGER_IP "
        aws ecr get-login-password --region $AWS_REGION | \
        docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com && \
        docker pull ${IMAGE_URI}
    "
}

# Login worker nodes to ECR and pull image
setup_worker_nodes() {
    for WORKER_IP in $WORKER_IPS; do
        ssh -o StrictHostKeyChecking=no -i $SSH_KEY_PATH ec2-user@$WORKER_IP "
            aws ecr get-login-password --region $AWS_REGION | \
            docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com && \
            docker pull ${IMAGE_URI}
        " >/dev/null 2>&1 || true
    done
}

# Deploy FastAPI stack to Docker Swarm
deploy_to_swarm() {
    ssh -o StrictHostKeyChecking=no -i $SSH_KEY_PATH ec2-user@${MANAGER_IP} "
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
}

# Test FastAPI endpoint
test_fastapi_endpoint() {
    sleep 30
    curl -s "http://${MANAGER_IP}:8001/health" >/dev/null 2>&1
}

# Execute deployment process
(determine_image_tag) &
spinner $! "Determining image tag..."

(ensure_ecr_repository) &
spinner $! "Ensuring ECR repository exists..."

(build_and_push_fastapi) &
spinner $! "Building and pushing FastAPI (tag: $IMAGE_TAG)..."

(get_infrastructure_info) &
spinner $! "Getting infrastructure info..."

(setup_manager_node) &
spinner $! "Setting up manager node..."

(setup_worker_nodes) &
spinner $! "Setting up worker nodes..."

(deploy_to_swarm) &
spinner $! "Deploying to Docker Swarm..."

(test_fastapi_endpoint) &
spinner $! "Testing FastAPI endpoint..."

echo "🎉 Deployment completed!"
echo "FastAPI: http://${MANAGER_IP}:8001"
echo "Visualizer: http://${MANAGER_IP}:8080"