# Project 2: Cloud-Native 3-Tier Web Application

## 🎯 Objective
Build a scalable **Web**, **App**, and **Database** tier application using cloud-native compute and networking services.

## 🧱 Architecture
**AWS**: VPC + EC2 + ALB + Auto Scaling + RDS  
**GCP**: VPC + Compute Engine + Cloud Load Balancing + Instance Groups + Cloud SQL  
**Azure**: VNet + Virtual Machines + Application Gateway + VM Scale Sets + Azure Database  

## 💡 App Idea
To-Do App or E-Commerce Web App deployed across clouds

## 🗺️ Diagram
```plaintext
[User] → [Load Balancer] → [App Instances] → [Managed Database]
```

## 📁 Project Structure
```
02-cloud-native-3tier-app/
├── aws/
│   ├── terraform/
│   ├── application/
│   └── README.md
├── gcp/
│   ├── terraform/
│   ├── application/
│   └── README.md
├── azure/
│   ├── terraform/
│   ├── application/
│   └── README.md
└── shared/
    ├── app-source/
    └── database-scripts/
```

## 🚀 Getting Started
1. Choose your cloud provider folder (aws, gcp, or azure)
2. Follow the specific implementation guide in each folder
3. Deploy the 3-tier architecture
4. Compare performance and costs across providers

## 🔄 Multi-Cloud Benefits
- **Architecture Comparison**: See how different clouds implement similar services
- **Cost Analysis**: Compare compute and database costs
- **Performance Testing**: Benchmark across different cloud regions
- **Skill Development**: Learn multiple cloud platforms