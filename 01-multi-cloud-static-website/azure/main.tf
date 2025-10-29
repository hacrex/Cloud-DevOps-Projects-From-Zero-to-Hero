terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Create Resource Group
resource "azurerm_resource_group" "website_rg" {
  name     = "${var.project_name}-rg"
  location = var.location

  tags = {
    Environment = var.environment
    Project     = "static-website"
  }
}

# Create Storage Account for static website
resource "azurerm_storage_account" "website_storage" {
  name                     = "${var.project_name}storage${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.website_rg.name
  location                 = azurerm_resource_group.website_rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"

  static_website {
    index_document     = "index.html"
    error_404_document = "404.html"
  }

  tags = {
    Environment = var.environment
    Project     = "static-website"
  }
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Upload website files to blob storage
resource "azurerm_storage_blob" "index_html" {
  name                   = "index.html"
  storage_account_name   = azurerm_storage_account.website_storage.name
  storage_container_name = "$web"
  type                   = "Block"
  source                 = "../index.html"
  content_type           = "text/html"
}

resource "azurerm_storage_blob" "styles_css" {
  name                   = "styles.css"
  storage_account_name   = azurerm_storage_account.website_storage.name
  storage_container_name = "$web"
  type                   = "Block"
  source                 = "../styles.css"
  content_type           = "text/css"
}

resource "azurerm_storage_blob" "script_js" {
  name                   = "script.js"
  storage_account_name   = azurerm_storage_account.website_storage.name
  storage_container_name = "$web"
  type                   = "Block"
  source                 = "../script.js"
  content_type           = "application/javascript"
}

# Create CDN Profile
resource "azurerm_cdn_profile" "website_cdn" {
  name                = "${var.project_name}-cdn"
  location            = azurerm_resource_group.website_rg.location
  resource_group_name = azurerm_resource_group.website_rg.name
  sku                 = "Standard_Microsoft"

  tags = {
    Environment = var.environment
    Project     = "static-website"
  }
}

# Create CDN Endpoint
resource "azurerm_cdn_endpoint" "website_endpoint" {
  name                = "${var.project_name}-endpoint"
  profile_name        = azurerm_cdn_profile.website_cdn.name
  location            = azurerm_resource_group.website_rg.location
  resource_group_name = azurerm_resource_group.website_rg.name

  origin {
    name      = "website-origin"
    host_name = azurerm_storage_account.website_storage.primary_web_host
  }

  delivery_rule {
    name  = "httpsRedirect"
    order = 1

    request_scheme_condition {
      operator     = "Equal"
      match_values = ["HTTP"]
    }

    url_redirect_action {
      redirect_type = "Found"
      protocol      = "Https"
    }
  }

  global_delivery_rule {
    cache_expiration_action {
      behavior = "Override"
      duration = "1.00:00:00"
    }

    cache_key_query_string_action {
      behavior = "IncludeAll"
    }
  }

  tags = {
    Environment = var.environment
    Project     = "static-website"
  }
}

# Create DNS Zone
resource "azurerm_dns_zone" "website_dns" {
  name                = var.domain_name
  resource_group_name = azurerm_resource_group.website_rg.name

  tags = {
    Environment = var.environment
    Project     = "static-website"
  }
}

# Create DNS CNAME record for CDN
resource "azurerm_dns_cname_record" "website_cname" {
  name                = "www"
  zone_name           = azurerm_dns_zone.website_dns.name
  resource_group_name = azurerm_resource_group.website_rg.name
  ttl                 = 300
  record              = azurerm_cdn_endpoint.website_endpoint.fqdn

  tags = {
    Environment = var.environment
    Project     = "static-website"
  }
}

# Create DNS A record for apex domain (using Azure Traffic Manager)
resource "azurerm_traffic_manager_profile" "website_tm" {
  name                   = "${var.project_name}-tm"
  resource_group_name    = azurerm_resource_group.website_rg.name
  traffic_routing_method = "Performance"

  dns_config {
    relative_name = var.project_name
    ttl           = 100
  }

  monitor_config {
    protocol                     = "HTTPS"
    port                         = 443
    path                         = "/"
    interval_in_seconds          = 30
    timeout_in_seconds           = 9
    tolerated_number_of_failures = 3
  }

  tags = {
    Environment = var.environment
    Project     = "static-website"
  }
}

# Create Traffic Manager Endpoint
resource "azurerm_traffic_manager_external_endpoint" "website_endpoint" {
  name       = "website-endpoint"
  profile_id = azurerm_traffic_manager_profile.website_tm.id
  target     = azurerm_cdn_endpoint.website_endpoint.fqdn
  weight     = 100
}

# Create Application Insights for monitoring
resource "azurerm_application_insights" "website_insights" {
  name                = "${var.project_name}-insights"
  location            = azurerm_resource_group.website_rg.location
  resource_group_name = azurerm_resource_group.website_rg.name
  application_type    = "web"

  tags = {
    Environment = var.environment
    Project     = "static-website"
  }
}

# Create Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "website_logs" {
  name                = "${var.project_name}-logs"
  location            = azurerm_resource_group.website_rg.location
  resource_group_name = azurerm_resource_group.website_rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = {
    Environment = var.environment
    Project     = "static-website"
  }
}