# Docker Swarm on AWS - FastAPI Upload Demo

🐳 **Automatiserad Docker Swarm-kluster med FastAPI på AWS**

Ett komplett projekt som visar hur man skapar ett 3-nods Docker Swarm-kluster på AWS med Infrastructure as Code (IaC) och deployer en FastAPI-applikation med image upload-funktionalitet.

## 🎯 Vad gör detta projekt?

- **Skapar automatiskt** en 3-nods Docker Swarm-kluster på AWS
- **Använder Terraform** för infrastruktur som kod
- **Deployer FastAPI-app** med image upload till ECR
- **Automatisk versionshantering** av container images
- **Komplett CI/CD pipeline** med build, push och deploy

## 🚀 Snabbstart

### Förutsättningar

- [Terraform](https://www.terraform.io/downloads) installerat
- [AWS CLI](https://aws.amazon.com/cli/) konfigurerat med ECR-behörigheter
- [Docker](https://docs.docker.com/get-docker/) installerat

### 1. Klona och konfigurera

```bash
git clone <detta-repo>
cd python-docker-swarm-demo

# Terraform konfigureras automatiskt med SSH-nycklar
```

### 2. En-kommando deployment (rekommenderat)

```bash
cd scripts
./first-time-deploy.sh
```

Detta kommer att:

1. Skapa infrastruktur med Terraform
2. Vänta på Docker Swarm-initialisering
3. Skapa ECR repository
4. Bygga och pusha FastAPI-appen
5. Deploya till swarm-klustret
6. Verifiera deployment

⏱️ **Total tid: ~5-7 minuter**

### 3. Testa din deployment

Dina tjänster kommer att vara tillgängliga på:

- **🚀 FastAPI Upload Demo**: `http://<manager-ip>:8001`
- **📊 Docker Visualizer**: `http://<manager-ip>:8080`
- **🌐 Nginx**: `http://<manager-ip>:80`

```bash
# Hämta manager IP
cd terraform
terraform output manager_public_ip

# SSH till manager för debugging
ssh -i ~/.ssh/docker-swarm-key.pem ec2-user@<manager-ip>

# Kolla kluster-status
docker node ls
docker service ls
```

### 4. Utvecklingsworkflow

När du gör kodändringar i [`app/`](app/):

```bash
cd scripts

# Auto-increment version och deploya
./deploy-to-swarm.sh

# Eller med custom version
IMAGE_TAG=v5 ./deploy-to-swarm.sh
```

### 5. Komplett cleanup

```bash
cd scripts
./cleanup-all.sh
```

Detta tar bort ALLT: infrastruktur, ECR repository, SSH-nycklar.

## 🛠️ Vad inkluderas?

### FastAPI Application

- **📁 Upload Interface**: Modern HTML-formulär för image uploads
- **🔗 REST API**: `/upload` endpoint för filhantering
- **❤️ Health Check**: `/health` endpoint för Docker Swarm
- **🐳 Multi-arch**: Stöd för AMD64 och ARM64

### Infrastructure (Terraform)

- **🔐 Security Groups**: Docker Swarm + FastAPI-portar
- **⚡ EC2 Instances**: 3x t3.micro (1 manager + 2 workers)
- **🔑 SSH Keys**: Automatiskt genererade och konfigurerade
- **🏷️ IAM Roles**: ECR-behörigheter för alla noder
- **🌐 Networking**: Optimerat för container communication

### Automation Scripts

- [`scripts/first-time-deploy.sh`](scripts/first-time-deploy.sh) - Komplett setup från scratch
- [`scripts/deploy-to-swarm.sh`](scripts/deploy-to-swarm.sh) - Deploy code changes
- [`scripts/build-push-fastapi.sh`](scripts/build-push-fastapi.sh) - Build och push till ECR
- [`scripts/cleanup-all.sh`](scripts/cleanup-all.sh) - Komplett borttagning
- [`scripts/utils.sh`](scripts/utils.sh) - Gemensamma utilities

### Container Registry

- **🏗️ AWS ECR**: Privat repository för container images
- **📈 Versionshantering**: Automatisk v1, v2, v3... tagging
- **🔄 Multi-arch Images**: AMD64 och ARM64 support
- **🔐 Säker Access**: IAM-baserad autentisering

## 💡 Utvecklingsguide

### Lokal utveckling

```bash
cd app
pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

### Felsökning

```bash
# SSH till manager
ssh -i ~/.ssh/docker-swarm-key.pem ec2-user@<manager-ip>

# Service logs
docker service logs fastapi-demo_fastapi-app

# Service status
docker service ps fastapi-demo_fastapi-app

# Node status
docker node ls
```

### Versionshantering

Deployment-scriptet hanterar versioner automatiskt:

- **Första deploy**: `v1`
- **Påföljande deploys**: Auto-increment till `v2`, `v3`, osv.
- **Custom versions**: `IMAGE_TAG=custom ./deploy-to-swarm.sh`
- **Development**: `IMAGE_TAG=dev-$(date +%s) ./deploy-to-swarm.sh`

## 💰 Kostnad

- **EC2 Instances**: 3x t3.micro ≈ $0.10/timme
- **ECR Storage**: ~$0.10/månad per GB
- **Data Transfer**: Minimal för demo
- **Total demo-kostnad**: ~$0.50 för 3 timmars testning

⚠️ **Glöm inte** att köra `./cleanup-all.sh` när du är klar!

## 🔧 Teknisk stack

- **Infrastructure**: Terraform + AWS (EC2, ECR, IAM)
- **Orchestration**: Docker Swarm
- **Application**: FastAPI + Python 3.11
- **Frontend**: HTML5 + CSS3
- **CI/CD**: Shell scripts + AWS CLI
- **Monitoring**: Docker Visualizer

## 📄 Licens

MIT License - Se [`LICENSE`](LICENSE) för detaljer.
