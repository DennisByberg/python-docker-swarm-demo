#!/bin/bash

# Install and configure Docker
install_docker() {
    dnf update -y
    dnf install -y docker
    systemctl start docker
    systemctl enable docker
    usermod -aG docker ec2-user
}

# Install AWS CLI v2 for ECR access and SSM parameter retrieval
install_aws_cli() {
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    ./aws/install
    rm -rf aws awscliv2.zip
    sleep 10
}

# Configure AWS region and login to ECR
configure_aws_and_ecr() {
    export AWS_DEFAULT_REGION=${aws_region}
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    aws ecr get-login-password \
        --region ${aws_region} | docker login \
        --username AWS \
        --password-stdin $ACCOUNT_ID.dkr.ecr.${aws_region}.amazonaws.com
}

# Wait for manager node to store the worker join token in SSM
get_swarm_token() {
    for i in {1..30}; do
        TOKEN=$(aws ssm get-parameter --name "/docker-swarm/worker-token" --region ${aws_region} --query 'Parameter.Value' --output text 2>/dev/null)
        if [ ! -z "$TOKEN" ] && [ "$TOKEN" != "None" ]; then
            break
        fi
        sleep 30
    done
    
    if [ -z "$TOKEN" ] || [ "$TOKEN" == "None" ]; then
        exit 1
    fi
}

# Join the Docker Swarm cluster as a worker node
join_swarm_cluster() {
    docker swarm join --token $TOKEN ${manager_private_ip}:2377
}

# Execute initialization process
install_docker
install_aws_cli
configure_aws_and_ecr
get_swarm_token
join_swarm_cluster