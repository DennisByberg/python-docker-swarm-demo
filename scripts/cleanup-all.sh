#!/bin/bash

source "$(dirname "$0")/utils.sh"

AWS_REGION="eu-north-1"
REPO_NAME="fastapi-upload-demo"

# Delete Infrastructure
echo -n "Deleting infrastructure..."
(cd ../terraform && terraform destroy -auto-approve) >/dev/null 2>&1 &
spinner

# Delete ECR Repository
echo -n "Deleting ECR repository..."
(
    aws ecr batch-delete-image \
        --repository-name $REPO_NAME \
        --region $AWS_REGION \
        --image-ids "$(aws ecr list-images --repository-name $REPO_NAME --region $AWS_REGION --query 'imageIds[*]' --output json)" \
        >/dev/null 2>&1
    
    aws ecr delete-repository \
        --repository-name $REPO_NAME \
        --region $AWS_REGION \
        --force \
        >/dev/null 2>&1
) &
spinner

# Delete SSH Key
echo -n "Deleting SSH key..."
(rm -f ~/.ssh/docker-swarm-key.pem) &
spinner

# Final message
echo "Cleanup completed! ✅"