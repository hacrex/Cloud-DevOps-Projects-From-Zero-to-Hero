# Project 3: Infrastructure as Code Across Clouds

## 🎯 Objective
Recreate your entire 3-tier architecture using **Infrastructure as Code (IaC)** across multiple cloud providers.

## 🧱 Architecture
**AWS**: Terraform AWS Provider + S3 Backend + DynamoDB State Lock  
**GCP**: Terraform Google Provider + Cloud Storage Backend + Cloud Firestore State Lock  
**Azure**: Terraform AzureRM Provider + Storage Account Backend + Cosmos DB State Lock  

## 💡 App Idea
Automate Project #2 deployment across all three cloud providers

## 🗺️ Diagram
```plaintext
[Terraform Code] → [Multi-Cloud Infrastructure]
```

## 📁 Project Structure
```
03-infrastructure-as-code/
├── aws/
├── gcp/
├── azure/
├── modules/
│   ├── networking/
│   ├── compute/
│   └── database/
└── shared/
    └── terraform-configs/
```

## 🚀 Getting Started
Learn Infrastructure as Code patterns across cloud providers.