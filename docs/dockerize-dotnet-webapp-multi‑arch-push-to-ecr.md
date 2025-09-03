# Dockerize .NET WebApp (Multi-Arch), Push to ECR

## 🎯 Goal

Manually scaffold a minimal ASP.NET Core MVC app, add a simple multi-stage Dockerfile, build a multi-arch image (amd64 + arm64), log in to ECR with AWS CLI, and push the image to your ECR repository created in the AWS Console.

## 📋 Prerequisites

- Docker Desktop running (with Buildx; Docker Desktop includes it by default)
- .NET SDK 9 (or compatible)
- AWS CLI configured (`aws sts get-caller-identity` works) with permissions for ECR
- Region: eu-west-1 (adjust commands if you use a different region)

## 📚 Learning Objectives

- Use `dotnet new` to scaffold a simple MVC web app
- Add a concise multi-stage Dockerfile for production
- Build and push a multi-arch image to Amazon ECR
- Perform the ECR repository creation in the AWS Console and log in via AWS CLI

## 📝 Step-by-Step Instructions

All commands below are run from `DockerSwarm/Exercise-App-To-Swarm` unless noted otherwise.

### Step 1: Scaffold the .NET MVC app

Create a new MVC project inside a local app folder:

```bash
mkdir -p app
cd app
dotnet new mvc -n DsDemoWeb -o DsDemoWeb
```

Add a Git ignore file using the .NET template (keeps your repo clean):

```bash
cd DsDemoWeb
dotnet new gitignore
```

For container development, comment out HTTPS redirection (optional, improves dev experience without TLS config).

Open `Program.cs` and comment this line if present:

```csharp
// app.UseHttpsRedirection();
```

### Step 2: Add a minimal multi-stage Dockerfile

Create `Dockerfile` in `app/DsDemoWeb` with the following contents:

```dockerfile
# Build & publish
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src
COPY *.csproj ./
RUN dotnet restore
COPY . .
RUN dotnet publish -c Release -o /app/publish

# Runtime
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS production
WORKDIR /app
EXPOSE 80
ENV ASPNETCORE_URLS=http://+:80
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "DsDemoWeb.dll"]
```

**Notes:**

- Builds in a clean SDK image, publishes to `/app/publish`, then copies only published bits to the runtime
- Exposes port 80 so you can publish a host port later (e.g., `-p 8081:80`)

### Step 3: Create an ECR repository (AWS Console)

1. Open the **AWS Console** → **ECR** → **Repositories** → **Create repository**
2. **Visibility**: Private
3. **Name**: `ds-demo-web` (or your preferred name)
4. **Region**: eu-west-1
5. **Create repository** and note the repo URI, e.g.:
   ```
   <account-id>.dkr.ecr.eu-west-1.amazonaws.com/ds-demo-web
   ```

**CLI alternative (optional):** Create the repository with AWS CLI instead of the Console:

```bash
AWS_REGION=eu-west-1
REPO=ds-demo-web

# Create the repo (idempotent)
aws ecr describe-repositories --repository-names "$REPO" --region "$AWS_REGION" >/dev/null 2>&1 || \
  aws ecr create-repository --repository-name "$REPO" --region "$AWS_REGION"

# Compute the repo URI for later steps
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REPO_URI=${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPO}
echo "Repo URI: $REPO_URI"
```

### Step 4: Log in to ECR with AWS CLI

Use the AWS CLI to log in Docker to your account's ECR registry:

```bash
AWS_REGION=eu-west-1
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws ecr get-login-password --region $AWS_REGION \
  | docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
```

### Step 5: Build and push a multi-arch image with Buildx

Now build and push a multi-arch image (arm64 + amd64) directly to ECR:

```bash
# Still in DockerSwarm/Exercise-App-To-Swarm/app/DsDemoWeb
AWS_REGION=eu-west-1
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REPO_URI=${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/ds-demo-web
IMAGE_TAG=v1

# Ensure a buildx builder is available
(docker buildx inspect my_builder >/dev/null 2>&1) || docker buildx create --name my_builder --use

# Build and push multi-arch
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t ${REPO_URI}:${IMAGE_TAG} \
  -f Dockerfile \
  --push \
  .
```

**Optional:** Inspect the manifest to verify both architectures are present:

```bash
docker buildx imagetools inspect ${REPO_URI}:${IMAGE_TAG} | sed -n '1,120p'
```

## 🧪 Final Tests

1. In **ECR (Console)**, open your `ds-demo-web` repository and verify the `v1` tag exists
2. **Pull test (optional)** on any machine:
   ```bash
   docker pull ${REPO_URI}:${IMAGE_TAG}
   ```
3. **Run locally (optional)**:
   ```bash
   docker run --rm -p 8081:80 ${REPO_URI}:${IMAGE_TAG}
   # Open http://localhost:8081/
   ```

## ✅ Expected Results

- The image is pushed to ECR with a multi-arch manifest
- The app starts and serves the MVC template page when run

## 🔧 Troubleshooting

### ECR login fails:

- Confirm `aws sts get-caller-identity` works
- Ensure `AWS_REGION` matches the repo region

### Buildx missing:

- Docker Desktop usually includes it
- Create a builder with `docker buildx create --use`

### Permission denied on push:

- Ensure your IAM user/role has ECR push permissions for the repo

### Port conflict:

- Change `-p 8081:80` to a free port

## 🚀 Next Steps

- Deploy this image to your Swarm cluster using `docker stack deploy` on the manager node
- For rolling updates, push a new tag (e.g., `v2`) and update the stack to use the new tag
