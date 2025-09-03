#!/bin/bash

# Install and start Docker
dnf update -y
dnf install -y docker
systemctl enable --now docker
usermod -aG docker ec2-user

# Wait for Docker to be ready
sleep 30

# Get join token from manager and join swarm
for i in {1..30}; do
  if token=$(curl -s http://${manager_private_ip}:8000/worker-token 2>/dev/null); then
    if [ ! -z "$token" ] && [ "$token" != "404: Not Found" ]; then
      docker swarm join --token $token ${manager_private_ip}:2377
      exit 0
    fi
  fi
  sleep 10
done

# If we get here, joining failed
exit 1