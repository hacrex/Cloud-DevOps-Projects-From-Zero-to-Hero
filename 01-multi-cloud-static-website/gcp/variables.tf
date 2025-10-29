variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
  default     = "us-central1"
}

variable "domain_name" {
  description = "The domain name for the website"
  type        = string
  default     = "example.com"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}