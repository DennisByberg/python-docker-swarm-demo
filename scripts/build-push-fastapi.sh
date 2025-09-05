#!/bin/bash

set -e 
source "$(dirname "$0")/utils.sh"

AWS_REGION="eu-north-1"
REPO_NAME="fastapi-upload-demo"
IMAGE_TAG=${IMAGE_TAG:-"v1"}
APP_DIR="../app"

# Get repository URI
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REPO_URI="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPO_NAME}"

# Login to ECR
echo -n "Logging into ECR..."
(
    aws ecr get-login-password --region $AWS_REGION | \
    docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
) >/dev/null 2>&1 &
spinner

# Build and push
echo -n "Building and pushing image..."
(
    cd $APP_DIR
    docker buildx build \
        --platform linux/amd64,linux/arm64 \
        -t ${REPO_URI}:${IMAGE_TAG} \
        -t ${REPO_URI}:latest \
        --push \
        .
) >/dev/null 2>&1 &
spinner

echo "Build completed! ✅"
echo "Image: ${REPO_URI}:${IMAGE_TAG}"