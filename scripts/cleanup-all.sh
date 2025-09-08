#!/bin/bash

set -e
source "$(dirname "$0")/utils.sh"

# Configuration variables
AWS_REGION="eu-north-1"
REPO_NAME="fastapi-upload-demo"
STACK_NAME="myapp"
SSH_KEY_PATH="~/.ssh/docker-swarm-key.pem"

# Remove Docker stack
(
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
) &
spinner $! "Removing Docker stack..."

# Scale down ASG
(
    cd ../terraform
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
) &
spinner $! "Scaling down Auto Scaling Group..."

# Destroy infrastructure
(cd ../terraform && terraform destroy -auto-approve) >/dev/null 2>&1 &
spinner $! "Destroying infrastructure..."

# Clean up ECR repository
(
    aws ecr delete-repository \
        --repository-name ${REPO_NAME} \
        --region ${AWS_REGION} \
        --force 2>/dev/null || true
) &
spinner $! "Cleaning up ECR repository..."

# Clean up SSM parameters
(
    aws ssm delete-parameters \
        --names "/docker-swarm/worker-token" "/docker-swarm/manager-token" \
        --region ${AWS_REGION} >/dev/null 2>&1 || true
) &
spinner $! "Cleaning up SSM parameters..."
l
# Clean up SSH key
rm -f ~/.ssh/docker-swarm-key.pem 2>/dev/null || true

echo "🎉 Cleanup completed!"