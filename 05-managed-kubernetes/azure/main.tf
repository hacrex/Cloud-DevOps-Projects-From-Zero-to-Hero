terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.10"
    }
  }
}

provider "azurerm" {
  features {}
}

# Create Resource Group
resource "azurerm_resource_group" "aks_rg" {
  name     = "${var.cluster_name}-rg"
  location = var.location

  tags = {
    Environment = var.environment
    Project     = "bookstore-aks"
  }
}

# Create Virtual Network
resource "azurerm_virtual_network" "aks_vnet" {
  name                = "${var.cluster_name}-vnet"
  address_space       = [var.vnet_cidr]
  location            = azurerm_resource_group.aks_rg.location
  resource_group_name = azurerm_resource_group.aks_rg.name

  tags = {
    Environment = var.environment
    Project     = "bookstore-aks"
  }
}

# Create Subnet for AKS
resource "azurerm_subnet" "aks_subnet" {
  name                 = "${var.cluster_name}-subnet"
  resource_group_name  = azurerm_resource_group.aks_rg.name
  virtual_network_name = azurerm_virtual_network.aks_vnet.name
  address_prefixes     = [var.subnet_cidr]
}

# Create Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "aks_logs" {
  name                = "${var.cluster_name}-logs"
  location            = azurerm_resource_group.aks_rg.location
  resource_group_name = azurerm_resource_group.aks_rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = {
    Environment = var.environment
    Project     = "bookstore-aks"
  }
}

# Create Container Registry
resource "azurerm_container_registry" "aks_acr" {
  name                = "${var.cluster_name}acr${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.aks_rg.name
  location            = azurerm_resource_group.aks_rg.location
  sku                 = "Standard"
  admin_enabled       = false

  tags = {
    Environment = var.environment
    Project     = "bookstore-aks"
  }
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Create User Assigned Identity for AKS
resource "azurerm_user_assigned_identity" "aks_identity" {
  name                = "${var.cluster_name}-identity"
  resource_group_name = azurerm_resource_group.aks_rg.name
  location            = azurerm_resource_group.aks_rg.location

  tags = {
    Environment = var.environment
    Project     = "bookstore-aks"
  }
}

# Assign Network Contributor role to AKS identity
resource "azurerm_role_assignment" "aks_network_contributor" {
  scope                = azurerm_virtual_network.aks_vnet.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks_identity.principal_id
}

# Assign AcrPull role to AKS identity
resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = azurerm_container_registry.aks_acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}

# Create AKS Cluster
resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.cluster_name
  location            = azurerm_resource_group.aks_rg.location
  resource_group_name = azurerm_resource_group.aks_rg.name
  dns_prefix          = var.cluster_name
  kubernetes_version  = var.kubernetes_version

  default_node_pool {
    name                = "default"
    node_count          = var.node_count
    vm_size             = var.vm_size
    vnet_subnet_id      = azurerm_subnet.aks_subnet.id
    type                = "VirtualMachineScaleSets"
    enable_auto_scaling = true
    min_count           = var.min_node_count
    max_count           = var.max_node_count
    max_pods            = 110
    os_disk_size_gb     = var.os_disk_size_gb

    upgrade_settings {
      max_surge = "10%"
    }

    tags = {
      Environment = var.environment
      Project     = "bookstore-aks"
    }
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks_identity.id]
  }

  # Network Profile
  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"
    dns_service_ip    = var.dns_service_ip
    service_cidr      = var.service_cidr
    load_balancer_sku = "standard"
  }

  # RBAC
  azure_active_directory_role_based_access_control {
    managed                = true
    admin_group_object_ids = var.admin_group_object_ids
    azure_rbac_enabled     = true
  }

  # Add-ons
  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.aks_logs.id
  }

  azure_policy_enabled = true

  http_application_routing_enabled = false

  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  # Maintenance window
  maintenance_window {
    allowed {
      day   = "Sunday"
      hours = [2, 3]
    }
  }

  tags = {
    Environment = var.environment
    Project     = "bookstore-aks"
  }

  depends_on = [
    azurerm_role_assignment.aks_network_contributor,
  ]
}

# Configure kubectl
data "azurerm_kubernetes_cluster" "aks" {
  name                = azurerm_kubernetes_cluster.aks.name
  resource_group_name = azurerm_resource_group.aks_rg.name
}

provider "kubernetes" {
  host                   = data.azurerm_kubernetes_cluster.aks.kube_config.0.host
  client_certificate     = base64decode(data.azurerm_kubernetes_cluster.aks.kube_config.0.client_certificate)
  client_key             = base64decode(data.azurerm_kubernetes_cluster.aks.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.aks.kube_config.0.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = data.azurerm_kubernetes_cluster.aks.kube_config.0.host
    client_certificate     = base64decode(data.azurerm_kubernetes_cluster.aks.kube_config.0.client_certificate)
    client_key             = base64decode(data.azurerm_kubernetes_cluster.aks.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.aks.kube_config.0.cluster_ca_certificate)
  }
}

# Install NGINX Ingress Controller
resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = "ingress-nginx"
  version    = "4.7.1"

  create_namespace = true

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-health-probe-request-path"
    value = "/healthz"
  }

  depends_on = [azurerm_kubernetes_cluster.aks]
}

# Install Cert-Manager
resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  namespace  = "cert-manager"
  version    = "v1.12.0"

  create_namespace = true

  set {
    name  = "installCRDs"
    value = "true"
  }

  depends_on = [azurerm_kubernetes_cluster.aks]
}

# Create ClusterIssuer for Let's Encrypt
resource "kubernetes_manifest" "cluster_issuer" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-prod"
    }
    spec = {
      acme = {
        server = "https://acme-v02.api.letsencrypt.org/directory"
        email  = var.letsencrypt_email
        privateKeySecretRef = {
          name = "letsencrypt-prod"
        }
        solvers = [{
          http01 = {
            ingress = {
              class = "nginx"
            }
          }
        }]
      }
    }
  }

  depends_on = [helm_release.cert_manager]
}

# Create namespace for bookstore app
resource "kubernetes_namespace" "bookstore" {
  metadata {
    name = "bookstore"
    labels = {
      name = "bookstore"
    }
  }
}

# Deploy bookstore application
resource "kubernetes_deployment" "bookstore_api" {
  metadata {
    name      = "bookstore-api"
    namespace = kubernetes_namespace.bookstore.metadata[0].name
    labels = {
      app = "bookstore-api"
    }
  }

  spec {
    replicas = 3

    selector {
      match_labels = {
        app = "bookstore-api"
      }
    }

    template {
      metadata {
        labels = {
          app = "bookstore-api"
        }
      }

      spec {
        container {
          image = "${azurerm_container_registry.aks_acr.login_server}/bookstore-api:latest"
          name  = "bookstore-api"

          port {
            container_port = 3000
          }

          env {
            name  = "NODE_ENV"
            value = "production"
          }

          env {
            name  = "PORT"
            value = "3000"
          }

          resources {
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "256Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 3000
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 3000
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }
        }
      }
    }
  }

  depends_on = [azurerm_kubernetes_cluster.aks]
}

# Create service for bookstore API
resource "kubernetes_service" "bookstore_api" {
  metadata {
    name      = "bookstore-api-service"
    namespace = kubernetes_namespace.bookstore.metadata[0].name
  }

  spec {
    selector = {
      app = "bookstore-api"
    }

    port {
      port        = 80
      target_port = 3000
    }

    type = "ClusterIP"
  }
}

# Create ingress for bookstore API
resource "kubernetes_ingress_v1" "bookstore_api" {
  metadata {
    name      = "bookstore-api-ingress"
    namespace = kubernetes_namespace.bookstore.metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class"                = "nginx"
      "cert-manager.io/cluster-issuer"             = "letsencrypt-prod"
      "nginx.ingress.kubernetes.io/rewrite-target" = "/"
    }
  }

  spec {
    tls {
      hosts       = ["api.${var.domain_name}"]
      secret_name = "bookstore-api-tls"
    }

    rule {
      host = "api.${var.domain_name}"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.bookstore_api.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.nginx_ingress]
}

# Create HPA for bookstore API
resource "kubernetes_horizontal_pod_autoscaler_v2" "bookstore_api" {
  metadata {
    name      = "bookstore-api-hpa"
    namespace = kubernetes_namespace.bookstore.metadata[0].name
  }

  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = "bookstore-api"
    }

    min_replicas = 2
    max_replicas = 10

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = 70
        }
      }
    }

    metric {
      type = "Resource"
      resource {
        name = "memory"
        target {
          type                = "Utilization"
          average_utilization = 80
        }
      }
    }
  }
}

# Create Public IP for Ingress
resource "azurerm_public_ip" "ingress_ip" {
  name                = "${var.cluster_name}-ingress-ip"
  resource_group_name = azurerm_kubernetes_cluster.aks.node_resource_group
  location            = azurerm_resource_group.aks_rg.location
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    Environment = var.environment
    Project     = "bookstore-aks"
  }
}

# Create DNS Zone
resource "azurerm_dns_zone" "aks_dns" {
  name                = var.domain_name
  resource_group_name = azurerm_resource_group.aks_rg.name

  tags = {
    Environment = var.environment
    Project     = "bookstore-aks"
  }
}

# Create DNS A record for API
resource "azurerm_dns_a_record" "api_record" {
  name                = "api"
  zone_name           = azurerm_dns_zone.aks_dns.name
  resource_group_name = azurerm_resource_group.aks_rg.name
  ttl                 = 300
  records             = [azurerm_public_ip.ingress_ip.ip_address]

  tags = {
    Environment = var.environment
    Project     = "bookstore-aks"
  }
}