# ☁️ Cloud & DevOps Projects – From Zero to Hero

Welcome to my collection of **end-to-end Cloud & DevOps projects** built on **AWS**, **Terraform**, **Kubernetes**, and **CI/CD automation**.

Each project is designed to simulate **real-world cloud infrastructure**, evolving step-by-step from basic serverless hosting to multi-region disaster recovery.  
This repository demonstrates expertise across **Infrastructure as Code (IaC)**, **Containers**, **GitOps**, **Monitoring**, and **Security**.

---

## 📚 Table of Contents
1. [Project 1: Serverless Static Website](#1-serverless-static-website)
2. [Project 2: The Classic 3-Tier Web Application](#2-the-classic-3-tier-web-application)
3. [Project 3: Automate Everything with Terraform](#3-automate-everything-with-terraform)
4. [Project 4: Containerize and Orchestrate](#4-containerize-and-orchestrate)
5. [Project 5: Provision an EKS Cluster with Custom Modules](#5-provision-an-eks-cluster-with-custom-modules)
6. [Project 6: Implement GitOps on EKS with ArgoCD](#6-implement-gitops-on-eks-with-argocd)
7. [Project 7: Centralized Logging & Monitoring](#7-centralized-logging--monitoring)
8. [Project 8: Secure Your Infrastructure](#8-secure-your-infrastructure)
9. [Project 9: Build an Event-Driven Architecture](#9-build-an-event-driven-architecture)
10. [Project 10: Multi-Region Disaster Recovery Strategy](#10-multi-region-disaster-recovery-strategy)

---

## 1️⃣ Serverless Static Website

### 🎯 Objective
Host a static website globally using **AWS S3** and **CloudFront**, secured with HTTPS.

### 🧱 Architecture
- Amazon S3 → Static Website Hosting  
- CloudFront → CDN for global low-latency delivery  
- AWS Certificate Manager → Free SSL/TLS  
- Route 53 → Custom Domain  
- GitHub Actions / CodePipeline → CI/CD Deployment  

### 💡 App Idea
Personal Portfolio or Tech Blog  

### 🗺️ Diagram
```plaintext
[GitHub] → [S3 Bucket] → [CloudFront] → [User]
                   ↳ [ACM HTTPS]
````

---

## 2️⃣ The Classic 3-Tier Web Application

### 🎯 Objective

Build a scalable **Web**, **App**, and **Database** tier app using core AWS compute and networking services.

### 🧱 Architecture

* VPC + Public & Private Subnets
* EC2 Instances (Web/App Tier)
* Application Load Balancer (ALB)
* Auto Scaling Groups
* RDS (MySQL/PostgreSQL)

### 💡 App Idea

To-Do App or E-Commerce Web App

### 🗺️ Diagram

```plaintext
[User] → [ALB] → [App EC2] → [RDS Database]
```

---

## 3️⃣ Automate Everything with Terraform

### 🎯 Objective

Recreate your entire 3-tier architecture using **Infrastructure as Code (IaC)**.

### 🧱 Architecture

* Terraform for provisioning
* AWS Provider Configuration
* Remote Backend (S3 + DynamoDB for state)

### 💡 App Idea

Automate Project #2 deployment

### 🗺️ Diagram

```plaintext
[Terraform Code] → [AWS Infrastructure]
```

---

## 4️⃣ Containerize and Orchestrate

### 🎯 Objective

Dockerize an application and deploy it on **ECS with Fargate (serverless containers)**.

### 🧱 Architecture

* Docker → Containerize the app
* ECR → Store container images
* ECS + Fargate → Deploy containers
* ALB → Distribute traffic

### 💡 App Idea

Flask or Node.js REST API

### 🗺️ Diagram

```plaintext
[User] → [ALB] → [ECS (Fargate Tasks)] → [ECR]
```

---

## 5️⃣ Provision an EKS Cluster with Custom Modules

### 🎯 Objective

Deploy a **production-ready Kubernetes cluster** using **custom Terraform modules**.

### 🧱 Architecture

* EKS Cluster (Control Plane + Nodes)
* Terraform Custom Modules for EKS, VPC, IAM
* Worker Node Groups and Role Mappings

### 💡 App Idea

Bookstore API or Microservices Demo

### 🗺️ Diagram

```plaintext
[Terraform Modules] → [EKS Cluster] → [Worker Nodes]
```

---

## 6️⃣ Implement GitOps on EKS with ArgoCD

### 🎯 Objective

Automate deployments to Kubernetes with **GitOps** using **ArgoCD**.

### 🧱 Architecture

* ArgoCD → Installed on EKS
* GitHub Repo → Source of Truth
* Helm Charts / Kustomize for manifests

### 💡 App Idea

Auto-deployed microservice updated via Git commits

### 🗺️ Diagram

```plaintext
[Git Repo] → [ArgoCD] → [EKS Namespace] → [Pods]
```

---

## 7️⃣ Centralized Logging & Monitoring

### 🎯 Objective

Implement observability for your EC2 and EKS workloads.

### 🧱 Architecture

* CloudWatch → Logs and Metrics
* OpenSearch → Log Analytics
* Managed Grafana → Dashboards

### 💡 App Idea

Visualize metrics and logs for Projects #2–#6

### 🗺️ Diagram

```plaintext
[App] → [CloudWatch Logs] → [OpenSearch] → [Grafana]
```

---

## 8️⃣ Secure Your Infrastructure

### 🎯 Objective

Apply **AWS Security Best Practices** for identity, access, and network layers.

### 🧱 Architecture

* IAM Roles & Policies (no static keys)
* AWS Secrets Manager → Secure credentials
* Security Groups & NACLs → Network protection
* AWS Config → Continuous compliance

### 💡 App Idea

Secure any of your previous app deployments

### 🗺️ Diagram

```plaintext
[User/Service] → [IAM Role] → [AWS Resource]
```

---

## 9️⃣ Build an Event-Driven Architecture

### 🎯 Objective

Create a **serverless image processing pipeline** triggered by S3 uploads.

### 🧱 Architecture

* S3 → Trigger for file upload
* Lambda → Image processing logic
* SNS/SQS → Notification or Queue decoupling
* Output → Processed S3 Bucket

### 💡 App Idea

Serverless image thumbnail generator

### 🗺️ Diagram

```plaintext
[S3 Upload] → [Lambda] → [Processed S3 Bucket]
                     ↳ [SNS Notification]
```

---

## 🔟 Multi-Region Disaster Recovery Strategy

### 🎯 Objective

Design a **highly available system** across multiple AWS regions.

### 🧱 Architecture

* RDS Cross-Region Replication
* Route 53 → Failover Routing Policy
* S3 → Cross-Region Replication (CRR)
* Backup Automation Scripts

### 💡 App Idea

Disaster recovery setup for your 3-tier app

### 🗺️ Diagram

```plaintext
[Region A (Primary)] ⇄ [Region B (Secondary)]
           ↑                    ↑
      [Route 53 Failover]    [RDS Replica]
```

---

## 🧠 Skills Gained

* AWS Core Services (EC2, S3, RDS, ECS, EKS, Lambda, etc.)
* Terraform & Infrastructure as Code
* CI/CD Automation (GitHub Actions, CodePipeline)
* Docker & Containerization
* GitOps with ArgoCD
* Cloud Security & IAM
* Observability (CloudWatch, Grafana, OpenSearch)
* High Availability & Disaster Recovery

---

## 🧩 Repository Structure

```plaintext
📦 aws-devops-projects/
 ┣ 📁 project-1-serverless-static-site/
 ┣ 📁 project-2-3tier-app/
 ┣ 📁 project-3-terraform-iac/
 ┣ 📁 project-4-ecs-fargate/
 ┣ 📁 project-5-eks-cluster/
 ┣ 📁 project-6-argocd-gitops/
 ┣ 📁 project-7-logging-monitoring/
 ┣ 📁 project-8-security-best-practices/
 ┣ 📁 project-9-event-driven-lambda/
 ┗ 📁 project-10-dr-multiregion/
```

---

## 🛠️ Prerequisites

* AWS Free Tier Account
* Terraform Installed
* Docker Installed
* kubectl Configured
* GitHub Actions Enabled

---

## 🚀 How to Use

1. Clone this repository

   ```bash
   git clone https://github.com/<your-username>/aws-devops-projects.git
   ```
2. Navigate to the project folder

   ```bash
   cd aws-devops-projects/project-1-serverless-static-site
   ```
3. Follow the instructions in each project’s folder

---

## 🌐 Author

**Ashvit K.**
Cloud & DevOps Engineer | Automation & Security Enthusiast

📧 [LinkedIn](https://www.linkedin.com/in/opswork/)
🌎 Portfolio – Coming Soon

---

⭐ *If you find this repository helpful, please consider starring it to support my work!*

```
