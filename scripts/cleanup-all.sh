#!/bin/bash

set -e
source "$(dirname "$0")/utils.sh"

# Configuration
AWS_REGION="eu-north-1"
REPO_NAME="fastapi-upload-demo"
STACK_NAME="myapp"
SSH_KEY_PATH="~/.ssh/docker-swarm-key.pem"

# Get terraform output value safely, returns empty string if not found
get_terraform_output() {
    local output_name="$1"
    cd ../terraform
    if terraform output "$output_name" >/dev/null 2>&1; then
        terraform output -raw "$output_name" 2>/dev/null || echo ""
    else
        echo ""
    fi
}

# Remove Docker stack from the swarm cluster
remove_docker_stack() {
    local manager_ip=$(get_terraform_output "manager_public_ip")
    
    if [ -n "$manager_ip" ]; then
        ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no \
            -i "$SSH_KEY_PATH" ec2-user@"$manager_ip" \
            "docker stack rm $STACK_NAME" >/dev/null 2>&1 || true
        sleep 30
    fi
}

# Scale Auto Scaling Group down to 0 instances
scale_down_asg() {
    local asg_name=$(get_terraform_output "autoscaling_group_name")
    
    if [ -n "$asg_name" ]; then
        aws autoscaling update-auto-scaling-group \
            --auto-scaling-group-name "$asg_name" \
            --min-size 0 \
            --max-size 0 \
            --desired-capacity 0 \
            --region "$AWS_REGION" >/dev/null 2>&1 || true
        sleep 60
    fi
}

# Completely remove S3 bucket and all contents
cleanup_s3_bucket() {
    local bucket_name=$(get_terraform_output "s3_bucket_name")
    
    if [ -n "$bucket_name" ]; then
        # Remove all objects (including versioned objects)
        aws s3api list-object-versions \
            --bucket "$bucket_name" \
            --region "$AWS_REGION" \
            --query 'Versions[].{Key:Key,VersionId:VersionId}' \
            --output text 2>/dev/null | while read key version_id; do
            if [ -n "$key" ] && [ -n "$version_id" ]; then
                aws s3api delete-object \
                    --bucket "$bucket_name" \
                    --key "$key" \
                    --version-id "$version_id" \
                    --region "$AWS_REGION" >/dev/null 2>&1 || true
            fi
        done
        
        # Remove all delete markers
        aws s3api list-object-versions \
            --bucket "$bucket_name" \
            --region "$AWS_REGION" \
            --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' \
            --output text 2>/dev/null | while read key version_id; do
            if [ -n "$key" ] && [ -n "$version_id" ]; then
                aws s3api delete-object \
                    --bucket "$bucket_name" \
                    --key "$key" \
                    --version-id "$version_id" \
                    --region "$AWS_REGION" >/dev/null 2>&1 || true
            fi
        done
        
        # Remove all current objects (in case versioning is disabled)
        aws s3 rm "s3://$bucket_name" --recursive --region "$AWS_REGION" >/dev/null 2>&1 || true
        
        # Wait for eventual consistency
        sleep 5
        
        # Delete the bucket itself
        aws s3api delete-bucket \
            --bucket "$bucket_name" \
            --region "$AWS_REGION" >/dev/null 2>&1 || true
    fi
}

# Destroy all Terraform-managed infrastructure
destroy_infrastructure() {
    cd ../terraform
    terraform destroy -auto-approve >/dev/null 2>&1
}

# Delete ECR repository and all images
cleanup_ecr() {
    aws ecr delete-repository \
        --repository-name "$REPO_NAME" \
        --region "$AWS_REGION" \
        --force >/dev/null 2>&1 || true
}

# Remove SSH private key file
cleanup_ssh_keys() {
    rm -f ~/.ssh/docker-swarm-key.pem >/dev/null 2>&1 || true
}

(remove_docker_stack) &
spinner $! "Removing Docker stack..."

(scale_down_asg) &
spinner $! "Scaling down Auto Scaling Group..."

(cleanup_s3_bucket) &
spinner $! "Cleaning up S3 bucket..."

(destroy_infrastructure) &
spinner $! "Destroying Terraform infrastructure..."

(cleanup_ecr) &
spinner $! "Cleaning up ECR repository..."

(cleanup_ssh_keys) &
spinner $! "Removing SSH keys..."

echo "🎉 Complete cleanup finished!"