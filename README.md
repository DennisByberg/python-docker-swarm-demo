# Docker Swarm on AWS - Infrastructure as Code Demo

🐳 **Automatiserad Docker Swarm-kluster på AWS med Terraform**

Ett projekt som visar hur man skapar och konfigurerar ett 3-nods Docker Swarm-kluster på AWS med Infrastructure as Code (IaC).

## 🎯 Vad gör detta projekt?

- **Skapar automatiskt** en 3-nods Docker Swarm-kluster på AWS
- **Använder Terraform** för infrastruktur som kod
- **Deployer demo-applikationer** (Nginx + Docker Visualizer)
- **Jämför manuell vs automatiserad** uppsättning

## 🏗️ Arkitektur

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Manager   │    │  Worker 1   │    │  Worker 2   │
│             │◄──►│             │◄──►│             │
│ Swarm Init  │    │ Auto-join   │    │ Auto-join   │
└─────────────┘    └─────────────┘    └─────────────┘
       │
       ▼
┌─────────────┐
│ Demo Stack  │
│ • Nginx     │
│ • Visualizer│
└─────────────┘
```

## 🚀 Snabbstart

### Förutsättningar

- [Terraform](https://www.terraform.io/downloads) installerat
- [AWS CLI](https://aws.amazon.com/cli/) konfigurerat
- EC2 Key Pair i AWS (eu-north-1 region)

### 1. Klona och konfigurera

```bash
git clone <detta-repo>
cd python-docker-swarm-demo

# Skapa terraform.tfvars
echo 'key_name = "ditt-key-pair-namn"' > terraform/terraform.tfvars
```

### 2. Deploy med Terraform

```bash
cd terraform
terraform init
terraform plan
terraform apply  # Skriv 'yes' för att bekräfta
```

⏱️ **Vänta ~3-4 minuter** medan klustret skapas och konfigureras automatiskt.

### 3. Testa din Docker Swarm

```bash
# SSH till manager-noden
ssh -i ~/.ssh/ditt-key.pem ec2-user@$(terraform output -raw manager_public_ip)

# Kolla kluster-status
docker node ls
docker service ls

# Besök webbapplikationerna
# Nginx:      http://<manager-ip>
# Visualizer: http://<manager-ip>:8080
```

### 4. Städa upp

```bash
terraform destroy  # Skriv 'yes' för att bekräfta
```

## 📚 Guider

- **👥 Manuell uppsättning:** [`docs/docker-swarm-on-aws.md`](docs/docker-swarm-on-aws.md)
- **🐳 .NET Containerization:** [`docs/dockerize-dotnet-webapp-multi‑arch-push-to-ecr.md`](docs/dockerize-dotnet-webapp-multi‑arch-push-to-ecr.md)

## 🛠️ Vad inkluderas?

### Infrastructure (Terraform)

- **Security Group** med Docker Swarm-portar
- **3 EC2-instanser** (1 manager + 2 workers)
- **Automatisk nyckelhantering** (SSH-nycklar genereras)
- **Automatisk Swarm-initialisering**

### Demo-applikationer

- **Nginx** - Enkel webbserver (3 replicas)
- **Docker Visualizer** - Visuell representation av klustret

### Automation Scripts

- [`scripts/manager-init.sh`](scripts/manager-init.sh) - Initialiserar Swarm manager
- [`scripts/worker-init.sh`](scripts/worker-init.sh) - Ansluter workers automatiskt

## 💰 Kostnad

- **t3.micro instanser** i 3 timmar ≈ $0.30 USD
- **Glöm inte** att köra `terraform destroy` när du är klar!

## 📖 Lärandemål

- Infrastructure as Code med Terraform
- Docker Swarm kluster-hantering
- AWS EC2 och Security Groups
- Automatisering vs manuell konfiguration
- Container orchestration basics

## 📄 Licens

MIT License - Se [`LICENSE`](LICENSE) för detaljer.
