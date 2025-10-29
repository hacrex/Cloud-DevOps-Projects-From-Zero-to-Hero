# Multi-Cloud Container Deployment

This project demonstrates how to deploy containerized applications across multiple cloud providers using their managed container services.

## Architecture Overview

### AWS Implementation
- **ECS Fargate**: Serverless container hosting
- **ECR**: Container registry
- **Application Load Balancer**: Traffic distribution
- **CloudWatch**: Monitoring and logging

### GCP Implementation
- **Cloud Run**: Serverless container hosting
- **Artifact Registry**: Container registry
- **Cloud Load Balancing**: Global traffic distribution
- **Cloud Monitoring**: Observability

### Azure Implementation
- **Container Apps**: Serverless container hosting
- **Container Registry**: Container registry
- **Application Gateway**: Traffic management
- **Application Insights**: Monitoring

## Application

The sample application is a **Bookstore API** built with Node.js and Express, featuring:

- RESTful API endpoints for book management
- Health checks and metrics
- Comprehensive error handling
- Security best practices
- Horizontal scaling capabilities

## Prerequisites

- Docker installed locally
- AWS CLI configured
- Google Cloud SDK configured
- Azure CLI configured
- Terraform >= 1.0 installed

## Local Development

### Build and Run Locally

```bash
# Install dependencies
npm install

# Run locally
npm start

# Build Docker image
docker build -t bookstore-api .

# Run container locally
docker run -p 3000:3000 bookstore-api
```

### API Endpoints

- `GET /` - API information
- `GET /health` - Health check
- `GET /metrics` - Application metrics
- `GET /api/books` - List all books
- `GET /api/books/:id` - Get book by ID
- `POST /api/books` - Create new book
- `PUT /api/books/:id` - Update book
- `DELETE /api/books/:id` - Delete book
- `POST /api/books/:id/purchase` - Purchase book

## Cloud Deployment

### AWS Deployment (ECS Fargate)

```bash
cd aws/
terraform init
terraform plan
terraform apply
```

### GCP Deployment (Cloud Run)

```bash
cd gcp/
terraform init
terraform plan -var="project_id=your-gcp-project"
terraform apply
```

### Azure Deployment (Container Apps)

```bash
cd azure/
terraform init
terraform plan
terraform apply
```

## Container Registry Setup

### Push to AWS ECR

```bash
# Get login token
aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin ACCOUNT_ID.dkr.ecr.us-west-2.amazonaws.com

# Build and tag
docker build -t bookstore-api .
docker tag bookstore-api:latest ACCOUNT_ID.dkr.ecr.us-west-2.amazonaws.com/bookstore-api:latest

# Push
docker push ACCOUNT_ID.dkr.ecr.us-west-2.amazonaws.com/bookstore-api:latest
```

### Push to GCP Artifact Registry

```bash
# Configure Docker
gcloud auth configure-docker us-central1-docker.pkg.dev

# Build and tag
docker build -t bookstore-api .
docker tag bookstore-api:latest us-central1-docker.pkg.dev/PROJECT_ID/bookstore-api/bookstore-api:latest

# Push
docker push us-central1-docker.pkg.dev/PROJECT_ID/bookstore-api/bookstore-api:latest
```

### Push to Azure Container Registry

```bash
# Login to ACR
az acr login --name myregistry

# Build and tag
docker build -t bookstore-api .
docker tag bookstore-api:latest myregistry.azurecr.io/bookstore-api:latest

# Push
docker push myregistry.azurecr.io/bookstore-api:latest
```

## Features

### Scalability
- **Auto Scaling**: Automatic scaling based on CPU/memory usage
- **Load Balancing**: Traffic distribution across multiple instances
- **Health Checks**: Automatic health monitoring and recovery

### Security
- **Container Security**: Non-root user, minimal base image
- **Network Security**: Private networking and security groups
- **Secrets Management**: Secure handling of sensitive data

### Monitoring
- **Application Metrics**: Custom metrics and health endpoints
- **Infrastructure Monitoring**: CPU, memory, network monitoring
- **Logging**: Centralized log collection and analysis
- **Alerting**: Automated alerts for failures and performance issues

## Performance Optimization

### Container Optimization
- Multi-stage Docker builds
- Minimal base images (Alpine Linux)
- Layer caching optimization
- Security scanning

### Application Optimization
- Connection pooling
- Caching strategies
- Compression
- Rate limiting

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Deploy to Cloud
on:
  push:
    branches: [main]

jobs:
  deploy-aws:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Deploy to AWS
        run: |
          # Build and push to ECR
          # Update ECS service
  
  deploy-gcp:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Deploy to GCP
        run: |
          # Build and push to Artifact Registry
          # Deploy to Cloud Run
  
  deploy-azure:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Deploy to Azure
        run: |
          # Build and push to ACR
          # Update Container App
```

## Cost Optimization

### AWS
- Use Fargate Spot for non-critical workloads
- Right-size container resources
- Implement auto-scaling policies

### GCP
- Use Cloud Run's pay-per-request model
- Configure minimum instances to zero
- Optimize container startup time

### Azure
- Use consumption-based pricing
- Configure scale-to-zero
- Monitor and optimize resource usage

## Troubleshooting

### Common Issues

1. **Container Won't Start**
   - Check container logs
   - Verify environment variables
   - Ensure health check endpoints are working

2. **High Latency**
   - Check resource allocation
   - Monitor database connections
   - Verify network configuration

3. **Scaling Issues**
   - Review scaling policies
   - Check resource limits
   - Monitor application metrics

### Debugging Commands

```bash
# AWS ECS
aws ecs describe-services --cluster CLUSTER_NAME --services SERVICE_NAME
aws logs get-log-events --log-group-name LOG_GROUP

# GCP Cloud Run
gcloud run services describe SERVICE_NAME --region=REGION
gcloud logging read "resource.type=cloud_run_revision"

# Azure Container Apps
az containerapp show --name APP_NAME --resource-group RG_NAME
az monitor log-analytics query --workspace WORKSPACE_ID --analytics-query "QUERY"
```

## Security Best Practices

- Use non-root containers
- Scan images for vulnerabilities
- Implement proper RBAC
- Use secrets management
- Enable audit logging
- Regular security updates