# Project 5: Managed Kubernetes Across Cloud Providers

## 🎯 Objective
Deploy **production-ready Kubernetes clusters** using **custom Terraform modules** across cloud providers.

## 🧱 Architecture
**AWS**: EKS + Custom Terraform Modules + VPC + IAM  
**GCP**: GKE + Custom Terraform Modules + VPC + IAM  
**Azure**: AKS + Custom Terraform Modules + VNet + Azure AD  

## 💡 App Idea
Bookstore API or Microservices Demo on multi-cloud Kubernetes

## 🗺️ Diagram
```plaintext
[Terraform Modules] → [Managed K8s Cluster] → [Worker Nodes]
```

## 📁 Project Structure
```
05-managed-kubernetes/
├── aws-eks/
├── gcp-gke/
├── azure-aks/
├── k8s-manifests/
└── terraform-modules/
```

## 🚀 Getting Started
Deploy and manage Kubernetes clusters across cloud providers.