# Quick Deploy Guide

Get up and running with multi-cloud DevOps projects in minutes! This guide provides the fastest path to deploy each project across AWS, GCP, and Azure.

## 🚀 Prerequisites Check

Before starting, ensure you have:
- [ ] Cloud provider CLI configured (aws, gcloud, az)
- [ ] Terraform installed
- [ ] Docker installed (for container projects)
- [ ] kubectl installed (for Kubernetes projects)

Quick verification:
```bash
aws sts get-caller-identity && echo "✅ AWS configured"
gcloud auth list && echo "✅ GCP configured"  
az account show && echo "✅ Azure configured"
terraform version && echo "✅ Terraform ready"
```

## 📋 Project Quick Deploy Matrix

| Project | AWS | GCP | Azure | Difficulty | Time |
|---------|-----|-----|-------|------------|------|
| 1. Static Website | ⚡ | ⚡ | ⚡ | Beginner | 5 min |
| 2. 3-Tier App | 🔥 | 🔥 | 🔥 | Intermediate | 15 min |
| 3. Terraform IaC | 🔥 | 🔥 | 🔥 | Intermediate | 10 min |
| 4. Containers | ⚡ | ⚡ | ⚡ | Beginner | 8 min |
| 5. Kubernetes | 🚀 | 🚀 | 🚀 | Advanced | 20 min |
| 6. GitOps | 🚀 | 🚀 | 🚀 | Advanced | 25 min |
| 7. Observability | 🔥 | 🔥 | 🔥 | Intermediate | 15 min |
| 8. Security | 🚀 | 🚀 | 🚀 | Advanced | 30 min |
| 9. Serverless | 🔥 | 🔥 | 🔥 | Intermediate | 12 min |
| 10. Disaster Recovery | 🚀 | 🚀 | 🚀 | Advanced | 45 min |

Legend: ⚡ Quick Start | 🔥 Moderate | 🚀 Advanced

---

## ⚡ Project 1: Static Website (5 minutes)

### One-Command Deploy

#### AWS
```bash
cd 01-multi-cloud-static-website/aws/
cat > terraform.tfvars << EOF
domain_name = "$(whoami)-demo.com"
bucket_name = "$(whoami)-static-site-$(date +%s)"
EOF
terraform init && terraform apply -auto-approve
echo "🎉 Website deployed: $(terraform output -raw website_url)"
```

#### GCP
```bash
cd 01-multi-cloud-static-website/gcp/
cat > terraform.tfvars << EOF
project_id = "$(gcloud config get-value project)"
domain_name = "$(whoami)-demo.com"
EOF
terraform init && terraform apply -auto-approve
echo "🎉 Website deployed: $(terraform output -raw website_url)"
```

#### Azure
```bash
cd 01-multi-cloud-static-website/azure/
cat > terraform.tfvars << EOF
project_name = "$(whoami)site"
domain_name = "$(whoami)-demo.com"
EOF
terraform init && terraform apply -auto-approve
echo "🎉 Website deployed: $(terraform output -raw website_url)"
```

### Test Deployment
```bash
curl -I $(terraform output -raw website_url)
```

---

## ⚡ Project 4: Containers (8 minutes)

### Build and Deploy

#### AWS ECS Fargate
```bash
cd 04-multi-cloud-containers/

# Build container
docker build -t bookstore-api .

# Deploy infrastructure
cd aws/
terraform init && terraform apply -auto-approve

# Get ECR URL and push
ECR_URL=$(terraform output -raw ecr_repository_url)
aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin $ECR_URL
docker tag bookstore-api:latest $ECR_URL:latest
docker push $ECR_URL:latest

# Update service
aws ecs update-service --cluster $(terraform output -raw cluster_name) --service $(terraform output -raw service_name) --force-new-deployment

echo "🎉 API deployed: $(terraform output -raw application_url)"
```

#### GCP Cloud Run
```bash
cd 04-multi-cloud-containers/gcp/

# One-command deploy with Cloud Build
gcloud run deploy bookstore-api \
  --source . \
  --region us-central1 \
  --allow-unauthenticated \
  --port 3000

echo "🎉 API deployed: $(gcloud run services describe bookstore-api --region us-central1 --format 'value(status.url)')"
```

#### Azure Container Apps
```bash
cd 04-multi-cloud-containers/azure/

# Deploy infrastructure
terraform init && terraform apply -auto-approve

# Build and push
ACR_NAME=$(terraform output -raw acr_name)
az acr build --registry $ACR_NAME --image bookstore-api:latest .

# Update container app
az containerapp update \
  --name $(terraform output -raw app_name) \
  --resource-group $(terraform output -raw resource_group_name) \
  --image $ACR_NAME.azurecr.io/bookstore-api:latest

echo "🎉 API deployed: $(terraform output -raw application_url)"
```

### Test API
```bash
APP_URL=$(terraform output -raw application_url)
curl $APP_URL/health
curl $APP_URL/api/books
```

---

## 🔥 Project 5: Kubernetes (20 minutes)

### Cluster Deploy

#### AWS EKS
```bash
cd 05-managed-kubernetes/aws/
cat > terraform.tfvars << EOF
cluster_name = "$(whoami)-cluster"
region = "us-west-2"
EOF
terraform init && terraform apply -auto-approve

# Configure kubectl
aws eks update-kubeconfig --region us-west-2 --name $(whoami)-cluster

# Deploy app
kubectl apply -f ../k8s-manifests/
kubectl wait --for=condition=available --timeout=300s deployment/bookstore-api -n bookstore

echo "🎉 Cluster ready: $(kubectl get nodes)"
```

#### GCP GKE
```bash
cd 05-managed-kubernetes/gcp/
cat > terraform.tfvars << EOF
project_id = "$(gcloud config get-value project)"
cluster_name = "$(whoami)-cluster"
EOF
terraform init && terraform apply -auto-approve

# Configure kubectl
gcloud container clusters get-credentials $(whoami)-cluster --region us-central1

# Deploy app
kubectl apply -f ../k8s-manifests/
kubectl wait --for=condition=available --timeout=300s deployment/bookstore-api -n bookstore

echo "🎉 Cluster ready: $(kubectl get nodes)"
```

#### Azure AKS
```bash
cd 05-managed-kubernetes/azure/
cat > terraform.tfvars << EOF
cluster_name = "$(whoami)-cluster"
location = "East US"
EOF
terraform init && terraform apply -auto-approve

# Configure kubectl
az aks get-credentials --resource-group $(whoami)-cluster-rg --name $(whoami)-cluster

# Deploy app
kubectl apply -f ../k8s-manifests/
kubectl wait --for=condition=available --timeout=300s deployment/bookstore-api -n bookstore

echo "🎉 Cluster ready: $(kubectl get nodes)"
```

### Test Kubernetes App
```bash
kubectl port-forward -n bookstore svc/bookstore-api-service 8080:80 &
curl http://localhost:8080/health
```

---

## 🔥 Project 7: Observability (15 minutes)

### Deploy Monitoring Stack

#### AWS (EKS + CloudWatch)
```bash
cd 07-multi-cloud-observability/aws/

# Install Prometheus + Grafana
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set grafana.adminPassword=admin123

# Deploy CloudWatch integration
terraform init && terraform apply -auto-approve

echo "🎉 Grafana: kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"
```

#### GCP (GKE + Cloud Monitoring)
```bash
cd 07-multi-cloud-observability/gcp/
cat > terraform.tfvars << EOF
project_id = "$(gcloud config get-value project)"
cluster_name = "$(whoami)-cluster"
notification_email = "admin@example.com"
EOF
terraform init && terraform apply -auto-approve

echo "🎉 Monitoring deployed: Check GCP Console > Monitoring"
```

#### Azure (AKS + Application Insights)
```bash
cd 07-multi-cloud-observability/azure/
cat > terraform.tfvars << EOF
cluster_name = "$(whoami)-cluster"
resource_group_name = "$(whoami)-cluster-rg"
notification_email = "admin@example.com"
EOF
terraform init && terraform apply -auto-approve

echo "🎉 Monitoring deployed: Check Azure Portal > Application Insights"
```

### Access Monitoring
```bash
# Grafana (AWS/GCP)
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
echo "Open http://localhost:3000 (admin/admin123)"

# Cloud-native dashboards
echo "AWS: https://console.aws.amazon.com/cloudwatch/"
echo "GCP: https://console.cloud.google.com/monitoring"
echo "Azure: https://portal.azure.com/#blade/Microsoft_Azure_Monitoring/AzureMonitoringBrowseBlade"
```

---

## 🚀 Multi-Cloud Deploy (All Providers)

### Deploy Same Project Across All Clouds
```bash
#!/bin/bash
PROJECT="01-multi-cloud-static-website"  # Change as needed

# AWS
cd $PROJECT/aws/
echo "domain_name = \"$(whoami)-aws.com\"" > terraform.tfvars
terraform init && terraform apply -auto-approve &
AWS_PID=$!

# GCP  
cd ../$PROJECT/gcp/
echo "project_id = \"$(gcloud config get-value project)\"" > terraform.tfvars
echo "domain_name = \"$(whoami)-gcp.com\"" >> terraform.tfvars
terraform init && terraform apply -auto-approve &
GCP_PID=$!

# Azure
cd ../$PROJECT/azure/
echo "project_name = \"$(whoami)azure\"" > terraform.tfvars
echo "domain_name = \"$(whoami)-azure.com\"" >> terraform.tfvars
terraform init && terraform apply -auto-approve &
AZURE_PID=$!

# Wait for all deployments
wait $AWS_PID && echo "✅ AWS deployed"
wait $GCP_PID && echo "✅ GCP deployed"  
wait $AZURE_PID && echo "✅ Azure deployed"

echo "🎉 Multi-cloud deployment complete!"
```

---

## 🧹 Quick Cleanup

### Destroy All Resources
```bash
# Single cloud cleanup
terraform destroy -auto-approve

# Multi-cloud cleanup
for cloud in aws gcp azure; do
  cd $cloud/
  terraform destroy -auto-approve
  cd ..
done

# Kubernetes cleanup
kubectl delete namespace bookstore monitoring --ignore-not-found=true
```

### Emergency Cleanup Script
```bash
#!/bin/bash
# emergency-cleanup.sh - Nuclear option for stuck resources

echo "🚨 Emergency cleanup starting..."

# Terraform cleanup
find . -name "terraform.tfstate*" -delete
find . -name ".terraform" -type d -exec rm -rf {} +

# Kubernetes cleanup
kubectl delete all --all --all-namespaces --force --grace-period=0
kubectl delete pv --all --force --grace-period=0

# Cloud-specific cleanup
aws ecs list-clusters --query 'clusterArns[]' --output text | xargs -I {} aws ecs delete-cluster --cluster {}
gcloud container clusters list --format="value(name,zone)" | xargs -n2 gcloud container clusters delete --quiet
az group list --query "[?starts_with(name, '$(whoami)')].name" -o tsv | xargs -I {} az group delete --name {} --yes --no-wait

echo "🧹 Emergency cleanup complete!"
```

---

## 📊 Quick Status Check

### Health Check Script
```bash
#!/bin/bash
# health-check.sh - Verify all deployments

echo "🔍 Checking deployment status..."

# Terraform status
for dir in */terraform/; do
  cd $dir
  if [ -f terraform.tfstate ]; then
    echo "✅ $(basename $(dirname $dir)): $(terraform output 2>/dev/null | wc -l) resources"
  else
    echo "❌ $(basename $(dirname $dir)): No deployment found"
  fi
  cd - > /dev/null
done

# Kubernetes status
if kubectl cluster-info &>/dev/null; then
  echo "✅ Kubernetes: $(kubectl get nodes --no-headers | wc -l) nodes"
  echo "📊 Pods: $(kubectl get pods --all-namespaces --no-headers | wc -l) running"
else
  echo "❌ Kubernetes: Not connected"
fi

# Cloud resources
echo "☁️  AWS: $(aws ec2 describe-instances --query 'Reservations[].Instances[?State.Name==`running`]' --output text | wc -l) EC2 instances"
echo "☁️  GCP: $(gcloud compute instances list --format='value(name)' | wc -l) compute instances"  
echo "☁️  Azure: $(az vm list --query '[].name' -o tsv | wc -l) virtual machines"
```

---

## 🎯 Quick Testing

### Automated Test Suite
```bash
#!/bin/bash
# quick-test.sh - Test all deployments

echo "🧪 Running quick tests..."

# Test static websites
for url in $(terraform output -json 2>/dev/null | jq -r '.website_url.value // empty'); do
  if curl -sf $url > /dev/null; then
    echo "✅ Website: $url"
  else
    echo "❌ Website: $url"
  fi
done

# Test APIs
for url in $(terraform output -json 2>/dev/null | jq -r '.application_url.value // empty'); do
  if curl -sf $url/health > /dev/null; then
    echo "✅ API: $url"
  else
    echo "❌ API: $url"
  fi
done

# Test Kubernetes
if kubectl get pods --all-namespaces | grep -q Running; then
  echo "✅ Kubernetes: Pods running"
else
  echo "❌ Kubernetes: No running pods"
fi

echo "🎉 Quick tests complete!"
```

---

## 💡 Pro Tips

### Speed Up Deployments
```bash
# Parallel Terraform operations
terraform apply -parallelism=20

# Skip confirmation
terraform apply -auto-approve

# Use local state for testing
terraform init -backend=false

# Cache Docker layers
docker build --cache-from=previous-image .
```

### Quick Debugging
```bash
# Terraform debug
export TF_LOG=DEBUG

# Kubernetes debug
kubectl describe pod <pod-name>
kubectl logs -f <pod-name>

# Cloud provider debug
aws --debug
gcloud --verbosity=debug
az --debug
```

### Resource Tagging for Easy Cleanup
```bash
# Add to terraform.tfvars
tags = {
  Owner = "$(whoami)"
  Project = "quick-deploy"
  TTL = "24h"
}
```

## 🚨 Important Notes

- **Cost Warning**: These quick deploys create real cloud resources that incur costs
- **Security**: Default configurations prioritize speed over security
- **Cleanup**: Always run `terraform destroy` when done testing
- **Limits**: Check cloud provider quotas before deploying
- **Regions**: Deployments use default regions; modify for your location

## 🎉 Success!

If you've made it this far, you now have:
- ✅ Multi-cloud infrastructure deployed
- ✅ Applications running across providers
- ✅ Monitoring and observability set up
- ✅ Experience with cloud-native services

**Next Steps:**
1. Explore the deployed resources in cloud consoles
2. Modify configurations and redeploy
3. Set up CI/CD pipelines
4. Implement security best practices
5. Add custom monitoring and alerting

Happy cloud computing! 🌟