# 🔧 Troubleshooting Guide

Comprehensive troubleshooting guide for multi-cloud DevOps projects across AWS, Google Cloud Platform (GCP), and Microsoft Azure.

## 🚨 Emergency Quick Fixes

### Universal Cloud CLI Issues
```bash
# Check all cloud provider authentications
aws sts get-caller-identity || echo "❌ AWS not configured"
gcloud auth list --filter=status:ACTIVE || echo "❌ GCP not configured"
az account show || echo "❌ Azure not configured"

# Quick re-authentication
aws configure
gcloud auth login && gcloud auth application-default login
az login
```

### Terraform State Emergencies
```bash
# State file locked across all providers
terraform force-unlock LOCK_ID

# Nuclear option - remove all state locks
find . -name "*.tfstate*" -exec rm {} \;
find . -name ".terraform.lock.hcl" -exec rm {} \;
find . -name ".terraform" -type d -exec rm -rf {} \;
```

### Kubernetes Connection Issues
```bash
# Reset kubectl contexts for all clouds
aws eks update-kubeconfig --region us-west-2 --name cluster-name
gcloud container clusters get-credentials cluster-name --region us-central1
az aks get-credentials --resource-group rg-name --name cluster-name

# Emergency cluster access
kubectl config get-contexts
kubectl config use-context context-name
```

## 🔧 Cloud Provider Specific Issues

### AWS Issues

#### IAM and Permissions
**Problem**: Access denied errors
```
Error: AccessDenied: User is not authorized to perform action
```

**Solution**:
```bash
# Check current permissions
aws sts get-caller-identity
aws iam get-user
aws iam list-attached-user-policies --user-name username

# Test specific permissions
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::account:user/username \
  --action-names s3:CreateBucket \
  --resource-arns arn:aws:s3:::bucket-name
```

#### EKS Cluster Issues
**Problem**: EKS cluster creation fails
```
Error: InvalidParameterException: Role is not authorized to perform sts:AssumeRole
```

**Solution**:
```bash
# Check EKS service role
aws iam get-role --role-name eks-service-role
aws iam list-attached-role-policies --role-name eks-service-role

# Create missing role
aws iam create-role --role-name eks-service-role \
  --assume-role-policy-document file://eks-trust-policy.json
```

#### ECS/Fargate Issues
**Problem**: ECS tasks fail to start
```
Error: CannotPullContainerError: pull image manifest has been retried
```

**Solution**:
```bash
# Check ECR permissions
aws ecr describe-repositories
aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin account.dkr.ecr.region.amazonaws.com

# Verify task definition
aws ecs describe-task-definition --task-definition task-name
aws ecs describe-services --cluster cluster-name --services service-name
```

### GCP Issues

#### Authentication and Projects
**Problem**: Project not found or access denied
```
Error: googleapi: Error 403: The caller does not have permission
```

**Solution**:
```bash
# Check current project and permissions
gcloud config get-value project
gcloud projects get-iam-policy PROJECT_ID

# Switch project
gcloud config set project PROJECT_ID

# Enable required APIs
gcloud services enable container.googleapis.com
gcloud services enable compute.googleapis.com
gcloud services enable storage.googleapis.com
```

#### GKE Cluster Issues
**Problem**: GKE cluster creation fails
```
Error: Insufficient regional quota to satisfy request
```

**Solution**:
```bash
# Check quotas
gcloud compute project-info describe --project PROJECT_ID

# Request quota increase
gcloud alpha compute quotas list --filter="metric:CPUS region:us-central1"

# Use different machine types or regions
gcloud container clusters create cluster-name --machine-type e2-micro
```

#### Cloud Run Issues
**Problem**: Cloud Run deployment fails
```
Error: Cloud Run error: The request failed because the service account does not exist
```

**Solution**:
```bash
# Check service accounts
gcloud iam service-accounts list

# Create service account
gcloud iam service-accounts create cloud-run-sa \
  --display-name="Cloud Run Service Account"

# Grant permissions
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:cloud-run-sa@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/run.invoker"
```

### Azure Issues

#### Authentication and Subscriptions
**Problem**: Subscription not found or access denied
```
Error: AuthorizationFailed: The client does not have authorization to perform action
```

**Solution**:
```bash
# Check current subscription
az account show
az account list --output table

# Set correct subscription
az account set --subscription "subscription-id"

# Check permissions
az role assignment list --assignee user@domain.com
```

#### AKS Cluster Issues
**Problem**: AKS cluster creation fails
```
Error: Operation failed with status: 'Bad Request'. Details: The credentials in ServicePrincipal are invalid
```

**Solution**:
```bash
# Create service principal
az ad sp create-for-rbac --name aks-service-principal --skip-assignment

# Check existing service principals
az ad sp list --display-name aks-service-principal

# Reset credentials
az ad sp credential reset --name aks-service-principal
```

#### Container Apps Issues
**Problem**: Container Apps deployment fails
```
Error: ContainerAppEnvironmentNotFound
```

**Solution**:
```bash
# Check Container Apps environment
az containerapp env list --resource-group rg-name

# Create environment
az containerapp env create \
  --name myenvironment \
  --resource-group rg-name \
  --location eastus
```

## 📁 Project-Specific Issues

### Project 1: Static Website Issues

#### Problem: S3 bucket name already exists
```bash
# Solution: Use unique bucket name
BUCKET_NAME="mysite-$(date +%s)-$(whoami)"
aws s3 mb s3://$BUCKET_NAME
```

#### Problem: CloudFront distribution not working
```bash
# Check distribution status
aws cloudfront list-distributions

# Wait for deployment (can take 15-20 minutes)
aws cloudfront wait distribution-deployed --id DISTRIBUTION_ID
```

#### Problem: SSL certificate validation stuck
```bash
# Check certificate status
aws acm list-certificates --region us-east-1

# Manually validate DNS records in Route 53
aws route53 list-resource-record-sets --hosted-zone-id ZONE_ID
```

### Project 2: 3-Tier App Issues

#### Problem: Flask app not starting
```bash
# Check Python version
python --version

# Install missing dependencies
pip install -r requirements.txt

# Check for port conflicts
lsof -i :5000
```

#### Problem: Database connection failed
```bash
# Check RDS instance status
aws rds describe-db-instances --db-instance-identifier your-db

# Test connectivity
telnet your-db-endpoint 3306

# Check security groups
aws ec2 describe-security-groups --group-ids sg-xxxxxxxxx
```

#### Problem: Load balancer health checks failing
```bash
# Check target group health
aws elbv2 describe-target-health --target-group-arn TARGET_GROUP_ARN

# Check application health endpoint
curl http://your-app-ip:5000/health

# Review ALB logs
aws logs filter-log-events --log-group-name /aws/applicationloadbalancer/app/your-alb
```

### Project 3: Terraform Issues

#### Problem: "Backend configuration changed"
```bash
# Reinitialize backend
terraform init -reconfigure

# Migrate state
terraform init -migrate-state
```

#### Problem: "Resource already exists"
```bash
# Import existing resource
terraform import aws_instance.example i-1234567890abcdef0

# Or remove from state
terraform state rm aws_instance.example
```

#### Problem: State file locked
```bash
# Check DynamoDB lock table
aws dynamodb scan --table-name terraform-state-lock

# Force unlock (use carefully)
terraform force-unlock LOCK_ID
```

#### Problem: Plan shows unexpected changes
```bash
# Refresh state
terraform refresh

# Show detailed diff
terraform plan -detailed-exitcode

# Check for drift
terraform plan -refresh-only
```

### Project 4: Container Issues

#### Problem: Docker build fails
```bash
# Check Docker daemon
docker info

# Build with verbose output
docker build --no-cache --progress=plain -t bookstore-api .

# Check disk space
df -h
docker system df
```

#### Problem: Container exits immediately
```bash
# Check container logs
docker logs container-name

# Run interactively
docker run -it bookstore-api /bin/sh

# Check health status
docker inspect container-name | grep Health
```

#### Problem: Port binding issues
```bash
# Check port usage
netstat -tulpn | grep :3000

# Kill process using port
sudo kill -9 $(lsof -t -i:3000)

# Use different port
docker run -p 3001:3000 bookstore-api
```

### Project 5: EKS Issues

#### Problem: kubectl not connecting to cluster
```bash
# Update kubeconfig
aws eks update-kubeconfig --name cluster-name --region us-west-2

# Check current context
kubectl config current-context

# Test connection
kubectl get nodes
```

#### Problem: Pods stuck in Pending state
```bash
# Check pod events
kubectl describe pod pod-name

# Check node resources
kubectl top nodes
kubectl describe nodes

# Check for taints
kubectl get nodes -o json | jq '.items[].spec.taints'
```

#### Problem: Load Balancer Controller not working
```bash
# Check controller pods
kubectl get pods -n kube-system | grep aws-load-balancer

# Check controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Verify IAM permissions
aws iam get-role --role-name AmazonEKSLoadBalancerControllerRole
```

#### Problem: Ingress not creating ALB
```bash
# Check ingress status
kubectl describe ingress ingress-name

# Check ingress class
kubectl get ingressclass

# Verify annotations
kubectl get ingress ingress-name -o yaml
```

### Project 6: GitOps Issues

#### Problem: ArgoCD not syncing
```bash
# Check application status
kubectl get applications -n argocd

# Check ArgoCD logs
kubectl logs -n argocd deployment/argocd-application-controller

# Force sync
argocd app sync app-name
```

#### Problem: Git repository access issues
```bash
# Check repository credentials
kubectl get secrets -n argocd

# Test Git access
git clone https://github.com/user/repo.git

# Update repository credentials
argocd repo add https://github.com/user/repo.git --username user --password token
```

### Project 7: Monitoring Issues

#### Problem: Prometheus not scraping metrics
```bash
# Check Prometheus targets
kubectl port-forward svc/prometheus-server 9090:80
# Visit http://localhost:9090/targets

# Check service discovery
kubectl get servicemonitor -A

# Verify metrics endpoint
curl http://service-ip:port/metrics
```

#### Problem: Grafana dashboards not loading
```bash
# Check Grafana logs
kubectl logs -n monitoring deployment/prometheus-grafana

# Reset admin password
kubectl get secret prometheus-grafana -n monitoring -o jsonpath="{.data.admin-password}" | base64 --decode

# Check data source configuration
# Login to Grafana and verify Prometheus data source
```

### Project 8: Security Issues

#### Problem: Network policies blocking traffic
```bash
# Check network policies
kubectl get networkpolicies -A

# Test connectivity
kubectl run test-pod --image=busybox --rm -it -- wget -qO- http://service-name:port

# Describe network policy
kubectl describe networkpolicy policy-name
```

#### Problem: RBAC permission denied
```bash
# Check current user permissions
kubectl auth can-i create pods

# Check role bindings
kubectl get rolebindings,clusterrolebindings -A | grep user-name

# Describe role
kubectl describe role role-name
```

### Project 9: Serverless Issues

#### Problem: Lambda function timeout
```bash
# Check function logs
aws logs tail /aws/lambda/function-name --follow

# Increase timeout
aws lambda update-function-configuration \
  --function-name function-name \
  --timeout 300

# Check memory usage
aws logs filter-log-events \
  --log-group-name /aws/lambda/function-name \
  --filter-pattern "REPORT"
```

#### Problem: S3 trigger not working
```bash
# Check bucket notification configuration
aws s3api get-bucket-notification-configuration --bucket bucket-name

# Verify Lambda permissions
aws lambda get-policy --function-name function-name

# Test trigger manually
aws lambda invoke \
  --function-name function-name \
  --payload file://test-event.json \
  response.json
```

### Project 10: Disaster Recovery Issues

#### Problem: RDS read replica lag
```bash
# Check replica status
aws rds describe-db-instances --db-instance-identifier replica-name

# Monitor replication lag
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name ReplicaLag \
  --dimensions Name=DBInstanceIdentifier,Value=replica-name \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-01T23:59:59Z \
  --period 3600 \
  --statistics Average
```

#### Problem: Route 53 failover not working
```bash
# Check health check status
aws route53 get-health-check --health-check-id health-check-id

# Test DNS resolution
dig your-domain.com
nslookup your-domain.com

# Check failover records
aws route53 list-resource-record-sets --hosted-zone-id zone-id
```

## 🔍 Debugging Tools and Commands

### AWS CLI Debugging
```bash
# Enable debug mode
aws s3 ls --debug

# Use specific profile
aws s3 ls --profile production

# Override region
aws s3 ls --region us-east-1
```

### Kubernetes Debugging
```bash
# Get all resources in namespace
kubectl get all -n namespace-name

# Check events
kubectl get events --sort-by=.metadata.creationTimestamp

# Debug pod issues
kubectl describe pod pod-name
kubectl logs pod-name -c container-name
kubectl exec -it pod-name -- /bin/sh
```

### Docker Debugging
```bash
# Check container processes
docker exec container-name ps aux

# Monitor container stats
docker stats container-name

# Inspect container configuration
docker inspect container-name
```

### Terraform Debugging
```bash
# Enable debug logging
export TF_LOG=DEBUG
terraform plan

# Show state
terraform show

# Validate configuration
terraform validate
```

## 📊 Monitoring and Alerting

### Set up CloudWatch Alarms
```bash
# CPU utilization alarm
aws cloudwatch put-metric-alarm \
  --alarm-name "High-CPU" \
  --alarm-description "Alarm when CPU exceeds 70%" \
  --metric-name CPUUtilization \
  --namespace AWS/EC2 \
  --statistic Average \
  --period 300 \
  --threshold 70 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2
```

### Check AWS Service Health
```bash
# Check AWS service status
curl -s https://status.aws.amazon.com/ | grep -i "service issues"

# Check specific service health
aws support describe-services
```

## 🆘 Getting Help

### AWS Support
- AWS Documentation: https://docs.aws.amazon.com/
- AWS Forums: https://forums.aws.amazon.com/
- AWS Support Center: https://console.aws.amazon.com/support/

### Community Resources
- Stack Overflow: Tag your questions with `aws`, `terraform`, `kubernetes`
- GitHub Issues: Check project repositories for known issues
- Reddit: r/aws, r/devops, r/kubernetes

### Professional Support
- AWS Professional Services
- AWS Partner Network (APN) consultants
- Third-party DevOps consultants

## 📝 Best Practices for Troubleshooting

1. **Enable Logging**: Always enable detailed logging for debugging
2. **Use Tags**: Tag all resources for easier identification
3. **Document Issues**: Keep a log of issues and solutions
4. **Test in Stages**: Deploy incrementally to isolate issues
5. **Monitor Costs**: Set up billing alerts to avoid surprises
6. **Backup Regularly**: Always have backups before making changes
7. **Use Version Control**: Track all configuration changes
8. **Follow Least Privilege**: Use minimal required permissions

Remember: Most issues are configuration-related. Double-check your settings, permissions, and network configurations first! 🔍
## 🐳
 Container and Kubernetes Issues

### Docker Issues

#### Image Build Problems
**Problem**: Docker build fails with permission denied
```
Error: permission denied while trying to connect to Docker daemon
```

**Solution**:
```bash
# Add user to docker group (Linux)
sudo usermod -aG docker $USER
newgrp docker

# Start Docker service
sudo systemctl start docker

# Check Docker status
docker version
docker info
```

#### Registry Push Issues
**Problem**: Cannot push to container registry
```
Error: denied: requested access to the resource is denied
```

**Solution**:
```bash
# AWS ECR
aws ecr get-login-password --region region | docker login --username AWS --password-stdin account.dkr.ecr.region.amazonaws.com

# GCP Artifact Registry
gcloud auth configure-docker region-docker.pkg.dev

# Azure Container Registry
az acr login --name registryname
```

### Kubernetes Common Issues

#### Pod Issues
**Problem**: Pods stuck in Pending state
```
Status: Pending
Reason: Insufficient cpu/memory
```

**Solution**:
```bash
# Check node resources
kubectl top nodes
kubectl describe nodes

# Check resource requests/limits
kubectl describe pod pod-name

# Scale cluster or adjust resources
kubectl patch deployment deployment-name -p '{"spec":{"template":{"spec":{"containers":[{"name":"container-name","resources":{"requests":{"cpu":"100m","memory":"128Mi"}}}]}}}}'
```

**Problem**: ImagePullBackOff errors
```
Status: ImagePullBackOff
Reason: Failed to pull image
```

**Solution**:
```bash
# Check image name and tag
kubectl describe pod pod-name

# Verify registry credentials
kubectl get secrets
kubectl create secret docker-registry regcred \
  --docker-server=registry-url \
  --docker-username=username \
  --docker-password=password

# Test image pull manually
docker pull image-name:tag
```

#### Service and Ingress Issues
**Problem**: Service not accessible
```
Error: Connection refused
```

**Solution**:
```bash
# Check service endpoints
kubectl get endpoints service-name
kubectl describe service service-name

# Test service connectivity
kubectl run test-pod --image=busybox --rm -it -- wget -qO- http://service-name:port

# Check network policies
kubectl get networkpolicies
```

**Problem**: Ingress not working
```
Error: 404 Not Found
```

**Solution**:
```bash
# Check ingress controller
kubectl get pods -n ingress-nginx
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx

# Verify ingress configuration
kubectl describe ingress ingress-name
kubectl get ingress -o yaml

# Test ingress controller
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80
```

## 🏗️ Terraform Issues

### State Management
**Problem**: State file corruption
```
Error: Failed to load state: state snapshot was created by Terraform v1.x.x, which is newer than current v1.y.y
```

**Solution**:
```bash
# Backup state
cp terraform.tfstate terraform.tfstate.backup

# Upgrade Terraform
terraform version
# Download latest version

# Migrate state
terraform init -upgrade
```

**Problem**: Resource drift detected
```
Plan: 0 to add, 5 to change, 0 to destroy
```

**Solution**:
```bash
# Refresh state
terraform refresh

# Show current state
terraform show

# Import drifted resources
terraform import resource_type.name resource_id

# Force replacement if needed
terraform apply -replace=resource_type.name
```

### Provider Issues
**Problem**: Provider version conflicts
```
Error: Incompatible provider version
```

**Solution**:
```bash
# Lock provider versions
cat > versions.tf << EOF
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}
EOF

# Reinitialize
terraform init -upgrade
```

### Resource Creation Failures
**Problem**: Resource already exists
```
Error: Resource already exists
```

**Solution**:
```bash
# Import existing resource
terraform import aws_s3_bucket.example bucket-name
terraform import google_storage_bucket.example bucket-name
terraform import azurerm_storage_account.example /subscriptions/sub-id/resourceGroups/rg/providers/Microsoft.Storage/storageAccounts/account

# Or remove from state
terraform state rm resource_type.name
```

## 🔍 Monitoring and Observability Issues

### Prometheus Issues
**Problem**: Prometheus not scraping targets
```
Status: DOWN
Error: Get "http://target:port/metrics": dial tcp: connect: connection refused
```

**Solution**:
```bash
# Check service discovery
kubectl get servicemonitors
kubectl describe servicemonitor monitor-name

# Verify metrics endpoint
kubectl port-forward svc/service-name 8080:port
curl http://localhost:8080/metrics

# Check Prometheus configuration
kubectl get configmap prometheus-config -o yaml
```

### Grafana Issues
**Problem**: Grafana shows no data
```
No data points found
```

**Solution**:
```bash
# Check data source configuration
kubectl port-forward svc/grafana 3000:80
# Open http://localhost:3000 and check data sources

# Verify Prometheus connectivity
kubectl exec -it grafana-pod -- wget -qO- http://prometheus:9090/api/v1/targets

# Check query syntax
# Use Prometheus UI to test queries first
```

### Cloud-Native Monitoring Issues
**Problem**: CloudWatch/Cloud Monitoring not receiving metrics
```
No metrics data available
```

**Solution**:
```bash
# AWS CloudWatch
aws logs describe-log-groups
aws cloudwatch list-metrics --namespace AWS/ECS

# GCP Cloud Monitoring
gcloud logging logs list
gcloud monitoring metrics list

# Azure Monitor
az monitor metrics list --resource resource-id
az monitor log-analytics workspace list
```

## 🔐 Security and Networking Issues

### Network Connectivity
**Problem**: Cannot reach services across clouds
```
Error: Connection timeout
```

**Solution**:
```bash
# Check security groups/firewall rules
aws ec2 describe-security-groups --group-ids sg-id
gcloud compute firewall-rules list
az network nsg rule list --resource-group rg --nsg-name nsg-name

# Test connectivity
telnet hostname port
nc -zv hostname port

# Check DNS resolution
nslookup hostname
dig hostname
```

### SSL/TLS Certificate Issues
**Problem**: Certificate validation fails
```
Error: certificate verify failed: unable to get local issuer certificate
```

**Solution**:
```bash
# Check certificate status
openssl s_client -connect hostname:443 -servername hostname

# AWS Certificate Manager
aws acm list-certificates
aws acm describe-certificate --certificate-arn arn

# GCP Managed Certificates
gcloud compute ssl-certificates list

# Azure Key Vault
az keyvault certificate list --vault-name vault-name
```

## 🚀 Performance Issues

### Slow Deployments
**Problem**: Terraform/kubectl operations are slow
```
Still creating... [10m0s elapsed]
```

**Solution**:
```bash
# Increase Terraform parallelism
terraform apply -parallelism=20

# Use kubectl with increased timeout
kubectl apply -f manifests/ --timeout=600s

# Check resource quotas and limits
kubectl describe limitrange
kubectl describe resourcequota
```

### Application Performance
**Problem**: High response times
```
Response time > 5 seconds
```

**Solution**:
```bash
# Check resource utilization
kubectl top pods
kubectl top nodes

# Scale applications
kubectl scale deployment app-name --replicas=5

# Check for resource constraints
kubectl describe pod pod-name | grep -A 5 "Limits\|Requests"

# Analyze with profiling tools
kubectl exec -it pod-name -- top
kubectl exec -it pod-name -- netstat -tulpn
```

## 🧹 Cleanup and Recovery

### Emergency Cleanup
```bash
#!/bin/bash
# emergency-cleanup.sh - Nuclear option for stuck resources

echo "🚨 Starting emergency cleanup..."

# Terraform cleanup
find . -name "terraform.tfstate*" -delete
find . -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null

# Kubernetes cleanup
kubectl delete all --all --all-namespaces --force --grace-period=0 2>/dev/null
kubectl delete pv --all --force --grace-period=0 2>/dev/null

# AWS cleanup
aws ecs list-clusters --query 'clusterArns[]' --output text | xargs -I {} aws ecs delete-cluster --cluster {} 2>/dev/null
aws ec2 describe-instances --query 'Reservations[].Instances[?State.Name==`running`].InstanceId' --output text | xargs -I {} aws ec2 terminate-instances --instance-ids {} 2>/dev/null

# GCP cleanup
gcloud container clusters list --format="value(name,zone)" | xargs -n2 gcloud container clusters delete --quiet 2>/dev/null
gcloud compute instances list --format="value(name,zone)" | xargs -n2 gcloud compute instances delete --quiet 2>/dev/null

# Azure cleanup
az group list --query "[?starts_with(name, '$(whoami)')].name" -o tsv | xargs -I {} az group delete --name {} --yes --no-wait 2>/dev/null

echo "🧹 Emergency cleanup complete!"
```

### Selective Resource Cleanup
```bash
# Clean up specific resource types
terraform state list | grep aws_instance | xargs -I {} terraform state rm {}
kubectl get pods --all-namespaces | grep Evicted | awk '{print $1 " " $2}' | xargs -n2 kubectl delete pod -n
```

## 📊 Diagnostic Commands

### Multi-Cloud Health Check
```bash
#!/bin/bash
# health-check.sh - Comprehensive system check

echo "🔍 Multi-Cloud Health Check"
echo "=========================="

# Cloud provider connectivity
echo "☁️  Cloud Providers:"
aws sts get-caller-identity &>/dev/null && echo "✅ AWS" || echo "❌ AWS"
gcloud auth list --filter=status:ACTIVE &>/dev/null && echo "✅ GCP" || echo "❌ GCP"
az account show &>/dev/null && echo "✅ Azure" || echo "❌ Azure"

# Tool versions
echo -e "\n🔧 Tool Versions:"
terraform version | head -1
docker --version
kubectl version --client --short 2>/dev/null

# Kubernetes clusters
echo -e "\n⚓ Kubernetes Clusters:"
kubectl config get-contexts -o name | while read ctx; do
  kubectl config use-context $ctx &>/dev/null
  if kubectl cluster-info &>/dev/null; then
    nodes=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
    echo "✅ $ctx: $nodes nodes"
  else
    echo "❌ $ctx: Not accessible"
  fi
done

# Resource counts
echo -e "\n📊 Resource Summary:"
echo "AWS EC2: $(aws ec2 describe-instances --query 'Reservations[].Instances[?State.Name==`running`]' --output text 2>/dev/null | wc -l)"
echo "GCP Compute: $(gcloud compute instances list --format='value(name)' 2>/dev/null | wc -l)"
echo "Azure VMs: $(az vm list --query '[].name' -o tsv 2>/dev/null | wc -l)"

echo -e "\n🎉 Health check complete!"
```

### Performance Monitoring
```bash
# Monitor resource usage across clouds
watch -n 5 '
echo "=== Kubernetes Resources ==="
kubectl top nodes 2>/dev/null || echo "No cluster connected"
kubectl top pods --all-namespaces 2>/dev/null | head -10

echo -e "\n=== Docker Resources ==="
docker stats --no-stream 2>/dev/null | head -5
'
```

## 🆘 Getting Help

### Documentation Resources
- **AWS**: [AWS Documentation](https://docs.aws.amazon.com/)
- **GCP**: [Google Cloud Documentation](https://cloud.google.com/docs)
- **Azure**: [Azure Documentation](https://docs.microsoft.com/azure/)
- **Terraform**: [Terraform Documentation](https://www.terraform.io/docs/)
- **Kubernetes**: [Kubernetes Documentation](https://kubernetes.io/docs/)

### Community Support
- **AWS**: [AWS Forums](https://forums.aws.amazon.com/), [AWS re:Post](https://repost.aws/)
- **GCP**: [Google Cloud Community](https://cloud.google.com/community)
- **Azure**: [Microsoft Q&A](https://docs.microsoft.com/answers/)
- **Terraform**: [HashiCorp Community](https://discuss.hashicorp.com/)
- **Kubernetes**: [Kubernetes Slack](https://kubernetes.slack.com/)

### Professional Support
- AWS Support Plans (Developer, Business, Enterprise)
- Google Cloud Support (Basic, Standard, Enhanced, Premium)
- Azure Support Plans (Basic, Developer, Standard, Professional Direct, Premier)
- HashiCorp Commercial Support
- CNCF Support Partners

### Emergency Contacts
```bash
# Create emergency contact list
cat > emergency-contacts.md << EOF
# Emergency Contacts

## Cloud Provider Support
- AWS: 1-800-xxx-xxxx (Account ID: xxx)
- GCP: 1-855-xxx-xxxx (Project ID: xxx)
- Azure: 1-800-xxx-xxxx (Subscription ID: xxx)

## Internal Team
- DevOps Lead: name@company.com
- Security Team: security@company.com
- On-call Engineer: oncall@company.com

## Escalation Procedures
1. Check troubleshooting guide
2. Search community forums
3. Contact internal team
4. Open support ticket
5. Escalate to management
EOF
```

## 🎯 Prevention Best Practices

### Infrastructure as Code
- Always use version control
- Implement code reviews
- Use consistent naming conventions
- Tag all resources appropriately
- Implement automated testing

### Monitoring and Alerting
- Set up comprehensive monitoring
- Create meaningful alerts
- Implement log aggregation
- Regular health checks
- Performance baselines

### Security
- Use least privilege access
- Enable audit logging
- Regular security scans
- Implement secrets management
- Network segmentation

### Disaster Recovery
- Regular backups
- Test recovery procedures
- Document runbooks
- Cross-region redundancy
- Automated failover

### Cost Management
- Set up billing alerts
- Regular cost reviews
- Resource tagging
- Automated cleanup
- Right-sizing resources

Remember: **Prevention is better than cure!** 🛡️

Most issues can be prevented with proper planning, monitoring, and following best practices. When problems do occur, systematic troubleshooting and good documentation are your best friends.