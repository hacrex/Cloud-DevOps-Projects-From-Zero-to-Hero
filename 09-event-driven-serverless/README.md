# Project 9: Event-Driven Serverless Architecture

## 🎯 Objective
Create **serverless image processing pipelines** triggered by cloud storage uploads across providers.

## 🧱 Architecture
**AWS**: S3 + Lambda + SNS/SQS + S3 Output  
**GCP**: Cloud Storage + Cloud Functions + Pub/Sub + Cloud Storage Output  
**Azure**: Blob Storage + Azure Functions + Service Bus + Blob Storage Output  

## 💡 App Idea
Multi-cloud serverless image thumbnail generator

## 🗺️ Diagram
```plaintext
[Storage Upload] → [Serverless Function] → [Processed Storage]
                              ↳ [Message Queue]
```

## 📁 Project Structure
```
09-event-driven-serverless/
├── aws/
├── gcp/
├── azure/
├── functions/
└── shared/
    └── image-processing/
```

## 🚀 Getting Started
Build event-driven serverless applications across cloud providers.