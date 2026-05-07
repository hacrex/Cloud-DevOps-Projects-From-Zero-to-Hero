# Project 6: GitOps Implementation on Kubernetes

## 🎯 Objective
Automate deployments to Kubernetes clusters with **GitOps** using **ArgoCD** across cloud providers.

## 🧱 Architecture
**AWS**: ArgoCD on EKS + GitHub + Helm/Kustomize  
**GCP**: ArgoCD on GKE + GitHub + Helm/Kustomize  
**Azure**: ArgoCD on AKS + GitHub + Helm/Kustomize  

## 💡 App Idea
Auto-deployed microservice updated via Git commits across cloud K8s clusters

## 🗺️ Diagram
```plaintext
[Git Repo] → [ArgoCD] → [K8s Namespace] → [Pods]
```

## 📁 Project Structure
```
06-gitops-kubernetes/
├── argocd-configs/
├── helm-charts/
├── kustomize/
└── applications/
```

## 🚀 Getting Started
Implement GitOps workflows across Kubernetes clusters.