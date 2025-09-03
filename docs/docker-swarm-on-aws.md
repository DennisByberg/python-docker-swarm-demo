# Docker Swarm on AWS

## 🎯 Goal

Provision a 3-node Docker Swarm cluster on AWS using the AWS Console, then manually configure the Swarm and deploy services via SSH. This provides hands-on experience with both AWS infrastructure setup and Docker Swarm administration.

## 📋 Prerequisites

- AWS Console access with EC2, IAM, and CloudFormation permissions
- SSH client installed locally
- EC2 Key Pair created in eu-west-1 region
- Basic familiarity with Linux command line

## 📚 Learning Objectives

- Navigate AWS Console to create infrastructure manually
- Connect to EC2 instances via SSH
- Initialize Docker Swarm cluster manually across multiple nodes
- Deploy and manage Docker services using command line
- Understand the difference between automated vs manual approaches

## 📝 Step-by-Step Instructions

### Step 1: Create Infrastructure via AWS Console

#### 1.1 Create Security Group

1. Navigate to **EC2 Console** → **Security Groups** → **Create security group**
2. **Security group name**: `docker-swarm-sg`
3. **Description**: Security group for Docker Swarm cluster
4. **VPC**: Select default VPC
5. **Inbound rules**:
   - **SSH**: Port 22, Source: 0.0.0.0/0 (Your IP recommended)
   - **HTTP**: Port 80, Source: 0.0.0.0/0
   - **Visualizer**: Port 8080, Source: 0.0.0.0/0
   - **Swarm Management**: Port 2377, Source: docker-swarm-sg (self-reference)
   - **Swarm Communication**: Port 7946 (TCP), Source: docker-swarm-sg
   - **Swarm Communication**: Port 7946 (UDP), Source: docker-swarm-sg
   - **Overlay Network**: Port 4789 (UDP), Source: docker-swarm-sg
6. Click **Create security group**

#### 1.2 Launch EC2 Instances

Navigate to **EC2 Console** → **Launch Instance**

**Configuration for Manager Node:**

- **Name**: `swarm-manager`
- **AMI**: Amazon Linux 2023
- **Instance type**: t3.small
- **Key pair**: Select your existing key pair
- **Network settings**:
  - **VPC**: Default VPC
  - **Subnet**: Any default subnet
  - **Auto-assign public IP**: Enable
  - **Security groups**: Select docker-swarm-sg
- **User data** (Advanced details):

```bash
#!/bin/bash

dnf update -y
dnf install -y docker
systemctl enable --now docker
usermod -aG docker ec2-user
```

Click **Launch instance**

**Repeat for 2 worker nodes**: `swarm-worker-1` and `swarm-worker-2`

#### 1.3 Note Instance Details

Once instances are running, note down:

- **Manager**: Public IP, Private IP
- **Worker 1**: Public IP, Private IP
- **Worker 2**: Public IP, Private IP

### Step 2: Initialize Docker Swarm via SSH

#### 2.1 Connect to Manager Node

```bash
# Replace with your key file and manager public IP
ssh -i ~/.ssh/your-key.pem ec2-user@<manager-public-ip>
```

#### 2.2 Initialize Swarm on Manager

```bash
# Replace with manager's private IP
sudo docker swarm init --advertise-addr <manager-private-ip>
```

**Expected output:**

```
Swarm initialized: current node (xyz123) is now a manager.

To add a worker to this swarm, run the following command:
    docker swarm join --token SWMTKN-1-xxx... <manager-private-ip>:2377
```

**Copy the join command** - you'll need it for the workers.

#### 2.3 Add Worker Nodes

**Connect to Worker 1:**

```bash
# New terminal window
ssh -i ~/.ssh/your-key.pem ec2-user@<worker1-public-ip>

# Run the join command from step 2.2
sudo docker swarm join --token SWMTKN-1-xxx... <manager-private-ip>:2377
```

**Connect to Worker 2:**

```bash
# New terminal window
ssh -i ~/.ssh/your-key.pem ec2-user@<worker2-public-ip>

# Run the same join command
sudo docker swarm join --token SWMTKN-1-xxx... <manager-private-ip>:2377
```

#### 2.4 Verify Cluster

Back on the manager node:

```bash
sudo docker node ls
```

**Expected output:**

```
ID                HOSTNAME                     STATUS    AVAILABILITY   MANAGER STATUS   ENGINE VERSION
abc123def456 *    ip-172-31-1-100.eu-west-1... Ready     Active         Leader           25.0.8
ghi789jkl012      ip-172-31-1-101.eu-west-1... Ready     Active                          25.0.8
mno345pqr678      ip-172-31-1-102.eu-west-1... Ready     Active                          25.0.8
```

### Step 3: Deploy Services Manually

#### 3.1 Create Docker Compose File

On the manager node, create the stack file:

```bash
cat > docker-stack.yml << 'EOF'
version: "3.8"

services:
  web:
    image: nginx:stable-alpine
    deploy:
      replicas: 3
      restart_policy:
        condition: on-failure
      update_config:
        parallelism: 1
        delay: 5s
    ports:
      - "80:80"
    networks:
      - webnet

  viz:
    image: dockersamples/visualizer:stable
    deploy:
      placement:
        constraints:
          - node.role == manager
    ports:
      - "8080:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    networks:
      - webnet

networks:
  webnet:
    driver: overlay
EOF
```

#### 3.2 Deploy the Stack

```bash
sudo docker stack deploy -c docker-stack.yml myapp
```

#### 3.3 Verify Deployment

```bash
# Check stack status
sudo docker stack ls

# Check services
sudo docker service ls

# Check service details
sudo docker service ps myapp_web
sudo docker service ps myapp_viz
```

### Step 4: Test and Scale Services

#### 4.1 Test Web Access

Open in browser:

- **Nginx**: `http://<any-node-public-ip>/`
- **Visualizer**: `http://<manager-public-ip>:8080/`

#### 4.2 Scale Services

```bash
# Scale up nginx to 5 replicas
sudo docker service scale myapp_web=5

# Check scaling
sudo docker service ps myapp_web

# Scale back down to 3
sudo docker service scale myapp_web=3
```

#### 4.3 Monitor Services

```bash
# Watch service status (Ctrl+C to exit)
watch sudo docker service ls

# View service logs
sudo docker service logs myapp_web
sudo docker service logs myapp_viz
```

### Step 5: Cleanup

#### 5.1 Remove Stack

On the manager node:

```bash
sudo docker stack rm myapp
```

#### 5.2 Leave Swarm (Optional)

If you want to reset the Swarm:

```bash
# On workers
sudo docker swarm leave

# On manager (force)
sudo docker swarm leave --force
```

#### 5.3 Terminate Instances

1. Go to **EC2 Console** → **Instances**
2. Select all 3 instances
3. **Instance State** → **Terminate Instance**
4. Confirm termination

#### 5.4 Delete Security Group

1. Go to **EC2 Console** → **Security Groups**
2. Select `docker-swarm-sg`
3. **Actions** → **Delete security group**

## 🧪 Verification Checklist

- 3 EC2 instances running with Docker installed
- Security group allows required Swarm ports
- Manager node shows Leader status
- 2 worker nodes show Ready/Active status
- nginx service responds on port 80 (all nodes)
- Visualizer UI accessible on port 8080 (manager)
- Scaling up/down works correctly
- Services distribute across nodes properly

## 🔧 Troubleshooting

### Can't SSH to instances:

- Check security group allows port 22 from your IP
- Verify you're using the correct key pair
- Ensure public IP assignment is enabled

### Worker can't join swarm:

- Check security group allows ports 2377, 7946, 4789
- Verify you're using private IP for advertise-addr
- Ensure instances are in same VPC/security group

### Services not accessible:

- Check security group allows ports 80, 8080
- Verify services are running: `sudo docker service ls`
- Check service placement: `sudo docker service ps <service>`

### Docker not installed:

- SSH to instance and run: `sudo dnf install -y docker && sudo systemctl enable --now docker`

## 💡 Key Differences vs Automated Approach

| Aspect           | Manual (This Exercise)      | Automated (Scripts)        |
| ---------------- | --------------------------- | -------------------------- |
| Setup Time       | 15-20 minutes               | 5-10 minutes               |
| Learning Value   | High (understand each step) | Medium (focus on patterns) |
| Reproducibility  | Low (human error prone)     | High (consistent results)  |
| Debugging        | Easy (direct access)        | Harder (through logs)      |
| Production Ready | No (manual steps)           | Yes (automated pipeline)   |

## 🎓 What You Learned

- **AWS Console Navigation**: Creating EC2 instances, security groups manually
- **SSH Management**: Connecting to and managing multiple remote instances
- **Docker Swarm Fundamentals**: Understanding manager/worker roles, join tokens
- **Service Deployment**: Creating and deploying multi-service applications
- **Operations**: Scaling, monitoring, and troubleshooting Docker services
- **Infrastructure Understanding**: Seeing the underlying resources automation creates

This manual approach gives you deeper understanding of what happens "under the hood" when using automated deployment scripts.
