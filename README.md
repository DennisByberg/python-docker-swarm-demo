# Docker Swarm on AWS - FastAPI Upload Demo with Load Balancer & Auto Scaling

🐳 **Production-ready Docker Swarm-kluster med FastAPI, Application Load Balancer och Auto Scaling på AWS**

Ett komplett projekt som visar hur man skapar ett skalbart Docker Swarm-kluster på AWS med Infrastructure as Code (IaC), Load Balancing, Auto Scaling och deployer en FastAPI-applikation med image upload-funktionalitet.

## 🎯 Vad gör detta projekt?

- **Skapar automatiskt** en skalbar Docker Swarm-kluster på AWS (1 manager + 2-6 workers)
- **Application Load Balancer** för high availability och load distribution
- **Auto Scaling Group** som automatiskt justerar worker-noder baserat på CPU-belastning
- **CloudWatch monitoring** med automatiska scaling policies
- **Använder Terraform** för infrastructure as code
- **Deployer FastAPI-app** med image upload till ECR
- **Production-ready setup** med health checks och redundans

## 🚀 Snabbstart

### Förutsättningar

- [Terraform](https://www.terraform.io/downloads) installerat
- [AWS CLI](https://aws.amazon.com/cli/) konfigurerat med ECR-behörigheter
- [Docker](https://docs.docker.com/get-docker/) installerat

### 1. Klona och konfigurera

```bash
git clone <detta-repo>
cd python-docker-swarm-demo

# Konfigurera region och instance-typer (valfritt)
# Redigera terraform/terraform.tfvars
```

### 2. En-kommando deployment

```bash
cd scripts
./first-time-deploy.sh
```

Detta kommer att:

1. 🏗️ Skapa komplett infrastruktur med Terraform (ALB + ASG + CloudWatch)
2. ⏳ Vänta på Docker Swarm-initialisering
3. 📦 Skapa ECR repository
4. 🔨 Bygga och pusha FastAPI-appen
5. 🚀 Deploya till swarm-klustret med load balancer
6. ✅ Verifiera deployment och health checks

⏱️ **Total tid: ~7-10 minuter**

### 3. Testa din deployment

Dina tjänster kommer att vara tillgängliga via **Load Balancer**:

- **🚀 FastAPI Upload Demo**: `http://<alb-dns>:8001`
- **📊 Docker Visualizer**: `http://<alb-dns>:8080`
- **🌐 Nginx**: `http://<alb-dns>`

```bash
# Hämta Load Balancer URL från output
cd terraform
terraform output load_balancer_dns
```

### 4. Komplett cleanup

```bash
cd scripts
./cleanup-all.sh
```

Detta tar bort ALLT: infrastruktur, ECR repository, SSH-nycklar.

## 🛠️ Vad inkluderas?

### FastAPI Application

- **📁 Upload Interface**: Modern HTML-formulär för image uploads
- **🔗 REST API**: `/upload` endpoint för filhantering
- **❤️ Health Check**: `/health` endpoint för Load Balancer health checks
- **🐳 Containerized**: Multi-stage Docker build

### Infrastructure (Terraform)

- **🌐 Application Load Balancer**: Traffic distribution med health checks
- **📈 Auto Scaling Group**: 2-6 worker-noder baserat på CPU-belastning
- **📊 CloudWatch**: Metrics, alarms och auto scaling policies
- **🔐 Security Groups**: Optimerade för ALB + Docker Swarm
- **⚡ EC2 Instances**: 1x manager (fast) + 2-6x workers (skalbar)
- **🔑 SSH Keys**: Automatiskt genererade och konfigurerade

### Container Registry

- **🏗️ AWS ECR**: Privat repository för container images
- **🔐 Säker Access**: IAM-baserad autentisering

## 💡 Utvecklingsguide

### Lokal utveckling

```bash
cd app
pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

### Monitoring & Felsökning

```bash
# SSH till manager
cd terraform
ssh -i ~/.ssh/docker-swarm-key.pem ec2-user@$(terraform output -raw manager_public_ip)

# Service status
docker service ls
docker service ps myapp_fastapi-app

# Node status
docker node ls
```

## ⚙️ Konfiguration

Anpassa deployment via [`terraform/terraform.tfvars`](terraform/terraform.tfvars):

```hcl
aws_region    = "eu-north-1"
instance_type = "t3.micro"
worker_count  = 2      # Initial workers
min_workers   = 2      # Minimum workers
max_workers   = 6      # Maximum workers
```

Anpassa scripts via variables i [`scripts/first-time-deploy.sh`](scripts/first-time-deploy.sh):

```bash
AWS_REGION="eu-north-1"
REPO_NAME="fastapi-upload-demo"
IMAGE_TAG="v1"
STACK_NAME="myapp"
```

## 🔧 Teknisk stack

- **Infrastructure**: Terraform, AWS (EC2, ALB, ASG, CloudWatch, ECR)
- **Container Orchestration**: Docker Swarm
- **Application**: FastAPI, Python 3.11
- **Frontend**: HTML5 + CSS3
- **Automation**: Bash scripts med spinner UX
