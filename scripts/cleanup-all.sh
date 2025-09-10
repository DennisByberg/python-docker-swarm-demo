#!/bin/bash

set -e
source "$(dirname "$0")/utils.sh"

# Configuration variables
AWS_REGION="eu-north-1"
REPO_NAME="fastapi-upload-demo"
STACK_NAME="myapp"
SSH_KEY_PATH="~/.ssh/docker-swarm-key.pem"

# Complete cleanup in background
(
    # Remove Docker stack
    cd ../terraform
    if terraform output manager_public_ip >/dev/null 2>&1; then
        MANAGER_IP=$(terraform output -raw manager_public_ip 2>/dev/null || echo "")
        if [ ! -z "$MANAGER_IP" ]; then
            ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no \
                -i ${SSH_KEY_PATH} ec2-user@${MANAGER_IP} \
                "docker stack rm ${STACK_NAME} || true" 2>/dev/null || true
            sleep 30
        fi
    fi

    # Scale down ASG
    if terraform output autoscaling_group_name >/dev/null 2>&1; then
        ASG_NAME=$(terraform output -raw autoscaling_group_name 2>/dev/null || echo "")
        if [ ! -z "$ASG_NAME" ]; then
            aws autoscaling update-auto-scaling-group \
                --auto-scaling-group-name "$ASG_NAME" \
                --min-size 0 \
                --max-size 0 \
                --desired-capacity 0 \
                --region ${AWS_REGION} 2>/dev/null || true
            sleep 60
        fi
    fi

    # Clean up S3 bucket (empty it first)
    if terraform output s3_bucket_name >/dev/null 2>&1; then
        S3_BUCKET_NAME=$(terraform output -raw s3_bucket_name 2>/dev/null || echo "")
        if [ ! -z "$S3_BUCKET_NAME" ]; then
            # Empty the bucket first (remove all objects and versions)
            aws s3api list-object-versions \
                --bucket "$S3_BUCKET_NAME" \
                --region ${AWS_REGION} \
                --query 'Versions[].{Key:Key,VersionId:VersionId}' \
                --output text 2>/dev/null | \
            while read key version_id; do
                if [ ! -z "$key" ] && [ ! -z "$version_id" ]; then
                    aws s3api delete-object \
                        --bucket "$S3_BUCKET_NAME" \
                        --key "$key" \
                        --version-id "$version_id" \
                        --region ${AWS_REGION} >/dev/null 2>&1 || true
                fi
            done
            
            # Remove delete markers
            aws s3api list-object-versions \
                --bucket "$S3_BUCKET_NAME" \
                --region ${AWS_REGION} \
                --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' \
                --output text 2>/dev/null | \
            while read key version_id; do
                if [ ! -z "$key" ] && [ ! -z "$version_id" ]; then
                    aws s3api delete-object \
                        --bucket "$S3_BUCKET_NAME" \
                        --key "$key" \
                        --version-id "$version_id" \
                        --region ${AWS_REGION} >/dev/null 2>&1 || true
                fi
            done
            
            aws s3 rm s3://"$S3_BUCKET_NAME" --recursive --region ${AWS_REGION} >/dev/null 2>&1 || true
        fi
    fi

    # Destroy infrastructure
    terraform destroy -auto-approve >/dev/null 2>&1

    # Clean up ECR repository
    aws ecr delete-repository \
        --repository-name ${REPO_NAME} \
        --region ${AWS_REGION} \
        --force 2>/dev/null || true

    # Clean up SSM parameters
    aws ssm delete-parameters \
        --names "/docker-swarm/worker-token" "/docker-swarm/manager-token" \
        --region ${AWS_REGION} >/dev/null 2>&1 || true

    # Clean up SSH key
    rm -f ~/.ssh/docker-swarm-key.pem 2>/dev/null || true

) &
spinner $! "Destroying AWS infrastructure and resources..."

echo "🎉 Complete cleanup finished!"