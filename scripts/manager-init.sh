#!/bin/bash

# Install and start Docker
dnf update -y
dnf install -y docker
systemctl enable --now docker
usermod -aG docker ec2-user

# Wait for Docker to be ready
sleep 30

# Initialize Docker Swarm
MANAGER_IP=$(hostname -I | awk '{print $1}')
docker swarm init --advertise-addr $MANAGER_IP

# Create and serve join token for workers
docker swarm join-token worker -q > /tmp/swarm-token
mkdir -p /tmp/swarm-tokens
cp /tmp/swarm-token /tmp/swarm-tokens/worker-token
cd /tmp/swarm-tokens
nohup python3 -m http.server 8000 > /dev/null 2>&1 &

# Create Docker stack file
cat > /home/ec2-user/docker-stack.yml << 'EOF'
version: "3.8"
services:
  web:
    image: nginx:stable-alpine
    deploy:
      replicas: 3
    ports:
      - "80:80"
    networks: [webnet]
  viz:
    image: dockersamples/visualizer:stable
    deploy:
      placement:
        constraints: [node.role == manager]
    ports:
      - "8080:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    networks: [webnet]
networks:
  webnet:
    driver: overlay
EOF

chown ec2-user:ec2-user /home/ec2-user/docker-stack.yml

# Wait for workers to join, then deploy
sleep 30
docker stack deploy -c /home/ec2-user/docker-stack.yml myapp