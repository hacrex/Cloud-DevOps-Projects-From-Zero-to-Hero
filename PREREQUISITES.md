# Prerequisites

Before you begin working with these multi-cloud DevOps projects, ensure you have the following tools and accounts set up across AWS, Google Cloud Platform (GCP), and Microsoft Azure.

## Required Cloud Accounts

### AWS Account
- Active AWS account with billing enabled
- IAM user with programmatic access
- Appropriate permissions for EC2, S3, EKS, Lambda, etc.

### Google Cloud Platform Account
- Active GCP account with billing enabled
- Service account with appropriate permissions
- Project with required APIs enabled

### Microsoft Azure Account
- Active Azure subscription
- Service principal with contributor access
- Resource group permissions

## Required Tools

### 1. Cloud CLIs

#### AWS CLI
```bash
# Install AWS CLI (macOS)
brew install awscli

# Install AWS CLI (Linux)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Install AWS CLI (Windows)
msiexec.exe /i https://awscli.amazonaws.com/AWSCLIV2.msi

# Configure AWS CLI
aws configure
```

#### Google Cloud SDK
```bash
# Install gcloud (macOS)
brew install --cask google-cloud-sdk

# Install gcloud (Linux)
curl https://sdk.cloud.google.com | bash
exec -l $SHELL

# Install gcloud (Windows)
# Download and run GoogleCloudSDKInstaller.exe

# Initialize gcloud
gcloud init
gcloud auth application-default login
```

#### Azure CLI
```bash
# Install Azure CLI (macOS)
brew install azure-cli

# Install Azure CLI (Linux)
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Install Azure CLI (Windows)
# Download and run Azure CLI MSI installer

# Login to Azure
az login
```

### 2. Infrastructure as Code

#### Terraform
```bash
# Install Terraform (macOS)
brew install terraform

# Install Terraform (Linux)
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# Install Terraform (Windows)
# Download from https://www.terraform.io/downloads.html

# Verify installation
terraform --version
```

### 3. Container Tools

#### Docker
```bash
# Install Docker (macOS)
brew install --cask docker

# Install Docker (Linux - Ubuntu)
sudo apt-get update
sudo apt-get install docker.io docker-compose
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER

# Install Docker (Windows)
# Download Docker Desktop from docker.com

# Verify installation
docker --version
docker-compose --version
```

### 4. Kubernetes Tools

#### kubectl
```bash
# Install kubectl (macOS)
brew install kubectl

# Install kubectl (Linux)
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install kubectl (Windows)
# Download from https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/

# Verify installation
kubectl version --client
```

#### Helm
```bash
# Install Helm (macOS)
brew install helm

# Install Helm (Linux)
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install Helm (Windows)
# Download from https://github.com/helm/helm/releases

# Verify installation
helm version
```

### 5. Development Tools

#### Git
```bash
# Install Git (macOS)
brew install git

# Install Git (Linux)
sudo apt-get install git

# Install Git (Windows)
# Download from https://git-scm.com/download/win

# Configure Git
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

#### Node.js and npm
```bash
# Install Node.js (macOS)
brew install node

# Install Node.js (Linux)
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install Node.js (Windows)
# Download from https://nodejs.org/

# Verify installation
node --version
npm --version
```

#### Python and pip
```bash
# Install Python (macOS)
brew install python

# Install Python (Linux)
sudo apt-get install python3 python3-pip

# Install Python (Windows)
# Download from https://python.org/

# Verify installation
python3 --version
pip3 --version
```

## Cloud Provider Setup

### AWS Configuration
```bash
# Configure AWS credentials
aws configure
# Enter: Access Key ID, Secret Access Key, Region (us-west-2), Output format (json)

# Verify configuration
aws sts get-caller-identity
aws s3 ls
```

### GCP Configuration
```bash
# Set default project
gcloud config set project YOUR_PROJECT_ID

# Set default region and zone
gcloud config set compute/region us-central1
gcloud config set compute/zone us-central1-a

# Enable required APIs
gcloud services enable container.googleapis.com
gcloud services enable compute.googleapis.com
gcloud services enable storage.googleapis.com
gcloud services enable dns.googleapis.com
gcloud services enable monitoring.googleapis.com
gcloud services enable logging.googleapis.com

# Verify configuration
gcloud config list
gcloud projects list
```

### Azure Configuration
```bash
# Login to Azure
az login

# Set default subscription
az account set --subscription "YOUR_SUBSCRIPTION_ID"

# Set default location
az configure --defaults location=eastus

# Register required providers
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.ContainerRegistry
az provider register --namespace Microsoft.Storage
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.Insights

# Verify configuration
az account show
az provider list --query "[?registrationState=='Registered']" --output table
```

## Required Permissions

### AWS IAM Permissions
Create an IAM user with the following managed policies:
- `AmazonEC2FullAccess`
- `AmazonS3FullAccess`
- `AmazonEKSClusterPolicy`
- `AmazonEKSWorkerNodePolicy`
- `AmazonEKS_CNI_Policy`
- `AmazonECRFullAccess`
- `AmazonRoute53FullAccess`
- `CloudWatchFullAccess`
- `AWSLambdaFullAccess`

### GCP IAM Roles
Create a service account with the following roles:
- `Compute Admin`
- `Storage Admin`
- `Kubernetes Engine Admin`
- `DNS Administrator`
- `Monitoring Admin`
- `Logging Admin`
- `Service Account User`

### Azure RBAC Roles
Assign the following roles to your user/service principal:
- `Contributor`
- `User Access Administrator`
- `Storage Account Contributor`
- `Network Contributor`
- `Monitoring Contributor`

## Environment Variables

Create a `.env` file in your project root:

```bash
# AWS Configuration
export AWS_REGION=us-west-2
export AWS_PROFILE=default

# GCP Configuration
export GOOGLE_PROJECT=your-gcp-project-id
export GOOGLE_REGION=us-central1
export GOOGLE_ZONE=us-central1-a

# Azure Configuration
export AZURE_SUBSCRIPTION_ID=your-subscription-id
export AZURE_LOCATION=eastus
export AZURE_RESOURCE_GROUP=your-resource-group

# Common Configuration
export DOMAIN_NAME=yourdomain.com
export NOTIFICATION_EMAIL=admin@yourdomain.com
export ENVIRONMENT=dev
```

## Domain Name Setup (Optional)

For projects requiring custom domains:

### Option 1: Use Cloud Provider DNS
- **AWS**: Register domain in Route 53
- **GCP**: Use Cloud DNS
- **Azure**: Use Azure DNS

### Option 2: External Domain Provider
- Register domain with any provider (GoDaddy, Namecheap, etc.)
- Configure DNS to point to cloud provider name servers

## Cost Management

### AWS
```bash
# Set up billing alerts
aws budgets create-budget --account-id YOUR_ACCOUNT_ID --budget file://budget.json
```

### GCP
```bash
# Set up billing alerts
gcloud billing budgets create --billing-account=BILLING_ACCOUNT_ID --display-name="DevOps Budget"
```

### Azure
```bash
# Set up cost alerts
az consumption budget create --budget-name "DevOps Budget" --amount 100 --time-grain Monthly
```

## Security Best Practices

### Multi-Cloud Security
- Use cloud-native identity and access management
- Enable multi-factor authentication on all accounts
- Implement least privilege access principles
- Use service accounts/managed identities instead of user credentials
- Enable audit logging on all cloud providers
- Regularly rotate access keys and certificates
- Use secrets management services (AWS Secrets Manager, GCP Secret Manager, Azure Key Vault)

### Network Security
- Use private networks and subnets
- Implement network security groups/firewalls
- Enable VPC/VNet flow logs
- Use private endpoints for cloud services

### Data Protection
- Enable encryption at rest and in transit
- Use cloud-native backup services
- Implement data retention policies
- Regular security assessments

## Verification Checklist

Before proceeding with the projects, verify:

- [ ] All cloud CLIs are installed and configured
- [ ] Terraform is installed and working
- [ ] Docker is installed and running
- [ ] kubectl and helm are installed
- [ ] Cloud provider permissions are correctly set
- [ ] Required APIs/services are enabled
- [ ] Environment variables are configured
- [ ] Domain name is available (if using custom domains)
- [ ] Billing alerts are configured
- [ ] Security best practices are implemented

## Next Steps

1. Choose your preferred cloud provider(s)
2. Clone the project repository
3. Navigate to the specific project folder
4. Follow the implementation guide for your chosen project
5. Start with Project 1 (Static Website) for a simple introduction