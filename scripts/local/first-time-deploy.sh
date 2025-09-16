#!/bin/bash

set -e
source "$(dirname "$0")/utils.sh"

# Configuration
AWS_REGION="eu-north-1"
REPO_NAME="fastapi-upload-demo"
IMAGE_TAG="v1"
STACK_NAME="myapp"
SSH_KEY_PATH="~/.ssh/docker-swarm-key.pem"

# Deploy infrastructure using Terraform
deploy_infrastructure() {
    cd ../../terraform
    terraform apply -auto-approve
    cd ../scripts/local
}

# Get outputs from Terraform
get_terraform_outputs() {
    cd ../../terraform
    MANAGER_IP=$(terraform output -raw manager_public_ip)
    ALB_DNS=$(terraform output -raw load_balancer_dns)
    ASG_NAME=$(terraform output -raw autoscaling_group_name)
    S3_BUCKET_NAME=$(terraform output -raw s3_bucket_name)
    DYNAMODB_TABLE_NAME=$(terraform output -raw dynamodb_table_name)
    cd ../scripts/local
}

# Wait for Docker Swarm to initialize
wait_for_swarm_init() {
    sleep 120
}

# Create ECR repository if needed
ensure_ecr_repository() {
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
}

# Build FastAPI image locally
build_fastapi_image() {
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    IMAGE_URI="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPO_NAME}:${IMAGE_TAG}"
    
    cd ../../app
    docker build -t ${REPO_NAME}:${IMAGE_TAG} -t ${IMAGE_URI} .
    cd ../scripts/local
}

# Push FastAPI image to ECR
push_fastapi_image() {
    aws ecr get-login-password --region ${AWS_REGION} | \
    docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
    
    docker push ${IMAGE_URI}
}

# Deploy basic stack with nginx and visualizer
deploy_basic_stack() {
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
}

# Deploy FastAPI service globally
deploy_fastapi_service() {
    ssh -o StrictHostKeyChecking=no -i ${SSH_KEY_PATH} ec2-user@${MANAGER_IP} "
        docker service create \
            --name ${STACK_NAME}_fastapi-app \
            --mode global \
            --publish 8001:8000 \
            --network ${STACK_NAME}_app-network \
            --with-registry-auth \
            --env AWS_REGION=${AWS_REGION} \
            --env S3_BUCKET_NAME=${S3_BUCKET_NAME} \
            --env DYNAMODB_TABLE_NAME=${DYNAMODB_TABLE_NAME} \
            ${IMAGE_URI}
        
        for i in {1..60}; do
            if [ \$(docker service ls --filter name=${STACK_NAME}_fastapi-app --format '{{.Replicas}}' | cut -d'/' -f1) = '3' ]; then
                break
            fi
            sleep 1
        done
    "
}

# Wait for Load Balancer health checks
wait_for_health_checks() {
    sleep 120
}

# Test endpoints via Load Balancer
test_endpoints() {
    for i in {1..20}; do
        if curl -s "http://${ALB_DNS}:8001/health" >/dev/null 2>&1; then
            break
        fi
        sleep 15
    done
}

# Execute deployment process
(deploy_infrastructure) &
spinner $! "Deploying infrastructure with ALB + ASG..."

(get_terraform_outputs) &
spinner $! "Getting Terraform outputs..."

(wait_for_swarm_init) &
spinner $! "Waiting for Docker Swarm to initialize..."

(ensure_ecr_repository) &
spinner $! "Ensuring ECR repository exists..."

(build_fastapi_image) &
spinner $! "Building FastAPI image locally..."

(push_fastapi_image) &
spinner $! "Pushing FastAPI image to ECR..."

(deploy_basic_stack) &
spinner $! "Deploying basic stack to Docker Swarm..."

(deploy_fastapi_service) &
spinner $! "Deploying FastAPI service globally..."

(wait_for_health_checks) &
spinner $! "Waiting for Load Balancer health checks to pass..."

(test_endpoints) &
spinner $! "Testing endpoints via Load Balancer..."

echo "🎉 Deployment completed!"
echo "Nginx: http://${ALB_DNS}"
echo "Visualizer: http://${ALB_DNS}:8080"
echo "FastAPI: http://${ALB_DNS}:8001"
echo "SSH to manager: ssh -i ${SSH_KEY_PATH} ec2-user@${MANAGER_IP}"