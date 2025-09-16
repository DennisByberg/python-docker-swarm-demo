#!/bin/bash

set -e 
source "$(dirname "$0")/utils.sh"

# Configuration
AWS_REGION="eu-north-1"
REPO_NAME="fastapi-upload-demo"
IMAGE_TAG=${IMAGE_TAG:-"v1"}
APP_DIR="../../app"

# Get repository URI and account ID
get_repo_uri() {
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    REPO_URI="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPO_NAME}"
}

# Login to ECR
login_to_ecr() {
    aws ecr get-login-password --region $AWS_REGION | \
    docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
}

# Build and push multi-arch image
build_and_push_image() {
    cd $APP_DIR
    docker buildx build \
        --platform linux/amd64,linux/arm64 \
        -t ${REPO_URI}:${IMAGE_TAG} \
        -t ${REPO_URI}:latest \
        --push \
        .
}

# Get repository configuration
get_repo_uri

# Execute build process
(login_to_ecr) >/dev/null 2>&1 &
spinner $! "Logging into ECR..."

(build_and_push_image) >/dev/null 2>&1 &
spinner $! "Building and pushing image..."

echo "✅ Build completed!"
echo "Image: ${REPO_URI}:${IMAGE_TAG}"