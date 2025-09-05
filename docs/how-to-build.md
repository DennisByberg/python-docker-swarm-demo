# Complete Build and Deploy Process

## 🚀 One-command deployment (recommended for first time)

```bash
# Deploy everything from scratch
cd scripts
./first-time-deploy.sh
```

This will:

1. Create infrastructure with Terraform
2. Wait for Docker Swarm to initialize
3. Create ECR repository if needed
4. Build and push FastAPI app to ECR
5. Deploy FastAPI app to the swarm
6. Verify deployment

## 🔄 When you make code changes

If you've updated your FastAPI code (`app/main.py`, `app/templates/upload.html`, etc.):

```bash
cd scripts

# Auto-increment version (v1 -> v2 -> v3...)
./deploy-to-swarm.sh

# Or specify custom version
IMAGE_TAG=v5 ./deploy-to-swarm.sh
```

This will:

1. Automatically find next version number (or use your custom tag)
2. Build new Docker image with your changes
3. Push to ECR with new tag
4. Update the Docker Swarm service with new image
5. Test the deployment

## 🏗️ Manual step-by-step deployment

### 1. Infrastructure only (first time)

```bash
cd terraform
terraform apply -auto-approve
```

### 2. Build and push new image

```bash
cd scripts
# Use custom tag for your version
IMAGE_TAG=v3 ./build-push-fastapi.sh
```

### 3. Deploy to existing swarm

```bash
# Auto-increment deploy
./deploy-to-swarm.sh

# Or with specific tag
IMAGE_TAG=v3 ./deploy-to-swarm.sh
```

## 🐳 Development workflow

### Local development with auto-reload

```bash
cd app
pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Visit `http://localhost:8000` to see changes in real-time.

### Test and deploy to swarm

```bash
cd scripts

# Quick auto-increment deploy
./deploy-to-swarm.sh

# Development build with timestamp
IMAGE_TAG=dev-$(date +%s) ./deploy.sh
```

## 📍 After deployment

Your services will be available at:

- **FastAPI Upload Demo**: `http://<manager-ip>:8001`
- **Docker Visualizer**: `http://<manager-ip>:8080`
- **Nginx**: `http://<manager-ip>:80`

Get manager IP with:

```bash
cd terraform
terraform output manager_public_ip
```

## 🧹 Clean up

### Complete cleanup

```bash
cd scripts
./cleanup-all.sh
```

## 🔧 Version management

The deploy script automatically manages versions:

- **First deploy**: Creates `v1`
- **Subsequent deploys**: Auto-increments to `v2`, `v3`, etc.
- **Manual override**: Use `IMAGE_TAG=custom ./deploy-to-swarm.sh`
- **Development**: Use timestamps like `IMAGE_TAG=dev-$(date +%s) ./deploy-to-swarm.sh`
