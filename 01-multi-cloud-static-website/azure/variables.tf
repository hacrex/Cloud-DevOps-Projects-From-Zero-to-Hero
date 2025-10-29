variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "staticwebsite"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "East US"
}

variable "domain_name" {
  description = "Domain name for the website"
  type        = string
  default     = "example.com"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}