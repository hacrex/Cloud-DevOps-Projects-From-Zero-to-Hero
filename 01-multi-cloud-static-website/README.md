# Multi-Cloud Static Website

This project demonstrates how to deploy a static website across multiple cloud providers (AWS, GCP, and Azure) using Infrastructure as Code.

## Architecture Overview

### AWS Implementation
- **S3**: Static website hosting
- **CloudFront**: Global CDN
- **Route 53**: DNS management
- **Certificate Manager**: SSL/TLS certificates

### GCP Implementation
- **Cloud Storage**: Static website hosting
- **Cloud CDN**: Global content delivery
- **Cloud DNS**: DNS management
- **Load Balancer**: HTTPS termination and SSL certificates

### Azure Implementation
- **Storage Account**: Static website hosting
- **CDN**: Global content delivery
- **DNS Zone**: DNS management
- **Traffic Manager**: Global load balancing

## Prerequisites

- AWS CLI configured with appropriate permissions
- Google Cloud SDK configured with appropriate permissions
- Azure CLI configured with appropriate permissions
- Terraform >= 1.0 installed
- Domain name for custom domain setup

## Deployment Instructions

### AWS Deployment

```bash
cd aws/
terraform init
terraform plan -var="domain_name=yourdomain.com"
terraform apply
```

### GCP Deployment

```bash
cd gcp/
terraform init
terraform plan -var="project_id=your-gcp-project" -var="domain_name=yourdomain.com"
terraform apply
```

### Azure Deployment

```bash
cd azure/
terraform init
terraform plan -var="domain_name=yourdomain.com"
terraform apply
```

## Features

- **Global CDN**: Fast content delivery worldwide
- **HTTPS**: SSL/TLS encryption across all providers
- **Custom Domain**: Support for custom domain names
- **Monitoring**: Built-in monitoring and alerting
- **Cost Optimization**: Efficient resource utilization

## File Structure

```
01-multi-cloud-static-website/
├── aws/
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── gcp/
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── azure/
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── index.html
├── styles.css
├── script.js
└── README.md
```

## Customization

1. **Update Content**: Modify `index.html`, `styles.css`, and `script.js` to customize your website
2. **Domain Configuration**: Update the domain name in terraform variables
3. **SSL Certificates**: Configure SSL certificates for your domain
4. **Monitoring**: Set up monitoring and alerting based on your requirements

## Cost Considerations

- **AWS**: S3 storage + CloudFront data transfer + Route 53 queries
- **GCP**: Cloud Storage + Cloud CDN + Cloud DNS queries
- **Azure**: Storage Account + CDN + DNS Zone queries

## Security Best Practices

- Enable HTTPS-only access
- Configure proper CORS policies
- Use least privilege IAM policies
- Enable logging and monitoring
- Regular security audits

## Troubleshooting

### Common Issues

1. **DNS Propagation**: DNS changes can take up to 48 hours to propagate globally
2. **SSL Certificate Validation**: Ensure domain ownership verification is complete
3. **CORS Issues**: Configure proper CORS policies for cross-origin requests
4. **Cache Issues**: Clear CDN cache when updating content

### Useful Commands

```bash
# Check DNS propagation
nslookup yourdomain.com

# Test SSL certificate
openssl s_client -connect yourdomain.com:443

# Clear CloudFront cache (AWS)
aws cloudfront create-invalidation --distribution-id DISTRIBUTION_ID --paths "/*"
```

## Monitoring and Maintenance

- Set up uptime monitoring
- Configure alerting for failures
- Regular content updates
- Performance optimization
- Security updates