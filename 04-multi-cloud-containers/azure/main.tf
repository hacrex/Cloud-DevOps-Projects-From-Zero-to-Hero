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
resource "azurerm_resource_group" "bookstore_rg" {
  name     = "${var.project_name}-rg"
  location = var.location

  tags = {
    Environment = var.environment
    Project     = "bookstore-api"
  }
}

# Create Container Registry
resource "azurerm_container_registry" "bookstore_acr" {
  name                = "${var.project_name}acr${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.bookstore_rg.name
  location            = azurerm_resource_group.bookstore_rg.location
  sku                 = "Basic"
  admin_enabled       = true

  tags = {
    Environment = var.environment
    Project     = "bookstore-api"
  }
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Create Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "bookstore_logs" {
  name                = "${var.project_name}-logs"
  location            = azurerm_resource_group.bookstore_rg.location
  resource_group_name = azurerm_resource_group.bookstore_rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = {
    Environment = var.environment
    Project     = "bookstore-api"
  }
}

# Create Container App Environment
resource "azurerm_container_app_environment" "bookstore_env" {
  name                       = "${var.project_name}-env"
  location                   = azurerm_resource_group.bookstore_rg.location
  resource_group_name        = azurerm_resource_group.bookstore_rg.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.bookstore_logs.id

  tags = {
    Environment = var.environment
    Project     = "bookstore-api"
  }
}

# Create Container App
resource "azurerm_container_app" "bookstore_api" {
  name                         = "${var.project_name}-api"
  container_app_environment_id = azurerm_container_app_environment.bookstore_env.id
  resource_group_name          = azurerm_resource_group.bookstore_rg.name
  revision_mode                = "Single"

  template {
    container {
      name   = "bookstore-api"
      image  = "${azurerm_container_registry.bookstore_acr.login_server}/bookstore-api:latest"
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "NODE_ENV"
        value = "production"
      }

      env {
        name  = "PORT"
        value = "3000"
      }

      liveness_probe {
        transport = "HTTP"
        port      = 3000
        path      = "/health"
      }

      readiness_probe {
        transport = "HTTP"
        port      = 3000
        path      = "/health"
      }

      startup_probe {
        transport = "HTTP"
        port      = 3000
        path      = "/health"
      }
    }

    min_replicas = 1
    max_replicas = 10

    http_scale_rule {
      name                = "http-requests"
      concurrent_requests = 100
    }
  }

  ingress {
    allow_insecure_connections = false
    external_enabled           = true
    target_port                = 3000

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  registry {
    server   = azurerm_container_registry.bookstore_acr.login_server
    username = azurerm_container_registry.bookstore_acr.admin_username
    password_secret_name = "registry-password"
  }

  secret {
    name  = "registry-password"
    value = azurerm_container_registry.bookstore_acr.admin_password
  }

  tags = {
    Environment = var.environment
    Project     = "bookstore-api"
  }
}

# Create Application Gateway for custom domain
resource "azurerm_virtual_network" "bookstore_vnet" {
  name                = "${var.project_name}-vnet"
  resource_group_name = azurerm_resource_group.bookstore_rg.name
  location            = azurerm_resource_group.bookstore_rg.location
  address_space       = ["10.0.0.0/16"]

  tags = {
    Environment = var.environment
    Project     = "bookstore-api"
  }
}

resource "azurerm_subnet" "gateway_subnet" {
  name                 = "gateway-subnet"
  resource_group_name  = azurerm_resource_group.bookstore_rg.name
  virtual_network_name = azurerm_virtual_network.bookstore_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "gateway_ip" {
  name                = "${var.project_name}-gateway-ip"
  resource_group_name = azurerm_resource_group.bookstore_rg.name
  location            = azurerm_resource_group.bookstore_rg.location
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    Environment = var.environment
    Project     = "bookstore-api"
  }
}

# Create Application Gateway
resource "azurerm_application_gateway" "bookstore_gateway" {
  name                = "${var.project_name}-gateway"
  resource_group_name = azurerm_resource_group.bookstore_rg.name
  location            = azurerm_resource_group.bookstore_rg.location

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "gateway-ip-config"
    subnet_id = azurerm_subnet.gateway_subnet.id
  }

  frontend_port {
    name = "https-port"
    port = 443
  }

  frontend_port {
    name = "http-port"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "frontend-ip"
    public_ip_address_id = azurerm_public_ip.gateway_ip.id
  }

  backend_address_pool {
    name  = "bookstore-backend"
    fqdns = [azurerm_container_app.bookstore_api.latest_revision_fqdn]
  }

  backend_http_settings {
    name                  = "bookstore-http-settings"
    cookie_based_affinity = "Disabled"
    path                  = "/"
    port                  = 443
    protocol              = "Https"
    request_timeout       = 60
    host_name             = azurerm_container_app.bookstore_api.latest_revision_fqdn

    probe_name = "bookstore-probe"
  }

  probe {
    name                = "bookstore-probe"
    protocol            = "Https"
    path                = "/health"
    host                = azurerm_container_app.bookstore_api.latest_revision_fqdn
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3

    match {
      status_code = ["200"]
    }
  }

  http_listener {
    name                           = "https-listener"
    frontend_ip_configuration_name = "frontend-ip"
    frontend_port_name             = "https-port"
    protocol                       = "Https"
    ssl_certificate_name           = "bookstore-ssl"
  }

  http_listener {
    name                           = "http-listener"
    frontend_ip_configuration_name = "frontend-ip"
    frontend_port_name             = "http-port"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "https-rule"
    rule_type                  = "Basic"
    http_listener_name         = "https-listener"
    backend_address_pool_name  = "bookstore-backend"
    backend_http_settings_name = "bookstore-http-settings"
    priority                   = 100
  }

  request_routing_rule {
    name               = "http-redirect-rule"
    rule_type          = "Basic"
    http_listener_name = "http-listener"
    redirect_configuration_name = "http-to-https"
    priority           = 200
  }

  redirect_configuration {
    name                 = "http-to-https"
    redirect_type        = "Permanent"
    target_listener_name = "https-listener"
    include_path         = true
    include_query_string = true
  }

  ssl_certificate {
    name     = "bookstore-ssl"
    data     = filebase64("${path.module}/ssl/certificate.pfx")
    password = var.ssl_certificate_password
  }

  tags = {
    Environment = var.environment
    Project     = "bookstore-api"
  }
}

# Create DNS Zone
resource "azurerm_dns_zone" "bookstore_dns" {
  name                = var.domain_name
  resource_group_name = azurerm_resource_group.bookstore_rg.name

  tags = {
    Environment = var.environment
    Project     = "bookstore-api"
  }
}

# Create DNS A record
resource "azurerm_dns_a_record" "api_record" {
  name                = "api"
  zone_name           = azurerm_dns_zone.bookstore_dns.name
  resource_group_name = azurerm_resource_group.bookstore_rg.name
  ttl                 = 300
  records             = [azurerm_public_ip.gateway_ip.ip_address]

  tags = {
    Environment = var.environment
    Project     = "bookstore-api"
  }
}

# Create Application Insights
resource "azurerm_application_insights" "bookstore_insights" {
  name                = "${var.project_name}-insights"
  location            = azurerm_resource_group.bookstore_rg.location
  resource_group_name = azurerm_resource_group.bookstore_rg.name
  workspace_id        = azurerm_log_analytics_workspace.bookstore_logs.id
  application_type    = "web"

  tags = {
    Environment = var.environment
    Project     = "bookstore-api"
  }
}

# Create Action Group for alerts
resource "azurerm_monitor_action_group" "bookstore_alerts" {
  name                = "${var.project_name}-alerts"
  resource_group_name = azurerm_resource_group.bookstore_rg.name
  short_name          = "bookstore"

  email_receiver {
    name          = "admin"
    email_address = var.notification_email
  }

  tags = {
    Environment = var.environment
    Project     = "bookstore-api"
  }
}

# Create metric alert for high error rate
resource "azurerm_monitor_metric_alert" "high_error_rate" {
  name                = "${var.project_name}-high-error-rate"
  resource_group_name = azurerm_resource_group.bookstore_rg.name
  scopes              = [azurerm_container_app.bookstore_api.id]
  description         = "Alert when error rate is high"
  severity            = 2
  frequency           = "PT1M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "Microsoft.App/containerApps"
    metric_name      = "Requests"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 100

    dimension {
      name     = "ResponseCode"
      operator = "Include"
      values   = ["5xx"]
    }
  }

  action {
    action_group_id = azurerm_monitor_action_group.bookstore_alerts.id
  }

  tags = {
    Environment = var.environment
    Project     = "bookstore-api"
  }
}