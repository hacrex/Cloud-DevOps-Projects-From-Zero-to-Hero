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

# Get existing AKS cluster
data "azurerm_kubernetes_cluster" "aks" {
  name                = var.cluster_name
  resource_group_name = var.resource_group_name
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

# Get resource group
data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

# Create Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "monitoring" {
  name                = "${var.cluster_name}-monitoring-logs"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = {
    Environment = var.environment
    Project     = "bookstore-monitoring"
  }
}

# Create Application Insights
resource "azurerm_application_insights" "monitoring" {
  name                = "${var.cluster_name}-monitoring-insights"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  workspace_id        = azurerm_log_analytics_workspace.monitoring.id
  application_type    = "web"

  tags = {
    Environment = var.environment
    Project     = "bookstore-monitoring"
  }
}

# Create namespace for monitoring
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
    labels = {
      name = "monitoring"
    }
  }
}

# Install Prometheus using Helm
resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = "51.2.0"

  values = [
    yamlencode({
      prometheus = {
        prometheusSpec = {
          retention = "30d"
          storageSpec = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = "managed-premium"
                accessModes      = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = "50Gi"
                  }
                }
              }
            }
          }
          additionalScrapeConfigs = [
            {
              job_name = "azure-monitor"
              static_configs = [{
                targets = ["management.azure.com"]
              }]
              metrics_path = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/Microsoft.Insights/metrics"
              scheme       = "https"
            }
          ]
        }
        service = {
          type = "LoadBalancer"
          annotations = {
            "service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path" = "/-/healthy"
          }
        }
      }
      grafana = {
        adminPassword = var.grafana_admin_password
        service = {
          type = "LoadBalancer"
          annotations = {
            "service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path" = "/api/health"
          }
        }
        persistence = {
          enabled = true
          size    = "10Gi"
        }
        datasources = {
          "datasources.yaml" = {
            apiVersion = 1
            datasources = [
              {
                name   = "Prometheus"
                type   = "prometheus"
                url    = "http://prometheus-kube-prometheus-prometheus:9090"
                access = "proxy"
              },
              {
                name = "Azure Monitor"
                type = "grafana-azure-monitor-datasource"
                jsonData = {
                  subscriptionId                = data.azurerm_client_config.current.subscription_id
                  tenantId                     = data.azurerm_client_config.current.tenant_id
                  clientId                     = var.azure_client_id
                  azureLogAnalyticsSameAs      = false
                  logAnalyticsSubscriptionId   = data.azurerm_client_config.current.subscription_id
                  logAnalyticsTenantId         = data.azurerm_client_config.current.tenant_id
                  logAnalyticsClientId         = var.azure_client_id
                  logAnalyticsDefaultWorkspace = azurerm_log_analytics_workspace.monitoring.workspace_id
                }
                secureJsonData = {
                  clientSecret             = var.azure_client_secret
                  logAnalyticsClientSecret = var.azure_client_secret
                }
              },
              {
                name = "Application Insights"
                type = "grafana-azure-monitor-datasource"
                jsonData = {
                  subscriptionId   = data.azurerm_client_config.current.subscription_id
                  tenantId         = data.azurerm_client_config.current.tenant_id
                  clientId         = var.azure_client_id
                  appInsightsAppId = azurerm_application_insights.monitoring.app_id
                }
                secureJsonData = {
                  clientSecret = var.azure_client_secret
                }
              }
            ]
          }
        }
      }
      alertmanager = {
        alertmanagerSpec = {
          storage = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = "managed-premium"
                accessModes      = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = "10Gi"
                  }
                }
              }
            }
          }
        }
        config = {
          global = {
            smtp_smarthost = var.smtp_server
            smtp_from      = var.alert_email_from
          }
          route = {
            group_by        = ["alertname"]
            group_wait      = "10s"
            group_interval  = "10s"
            repeat_interval = "1h"
            receiver        = "web.hook"
          }
          receivers = [
            {
              name = "web.hook"
              email_configs = [
                {
                  to      = var.alert_email_to
                  subject = "AKS Alert: {{ .GroupLabels.alertname }}"
                  body    = "{{ range .Alerts }}{{ .Annotations.summary }}\n{{ .Annotations.description }}{{ end }}"
                }
              ]
            }
          ]
        }
      }
    })
  ]

  depends_on = [kubernetes_namespace.monitoring]
}

# Install Fluent Bit for log collection
resource "helm_release" "fluent_bit" {
  name       = "fluent-bit"
  repository = "https://fluent.github.io/helm-charts"
  chart      = "fluent-bit"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = "0.37.0"

  values = [
    yamlencode({
      config = {
        outputs = "[OUTPUT]\n    Name azure\n    Match *\n    customer_id ${azurerm_log_analytics_workspace.monitoring.workspace_id}\n    shared_key ${azurerm_log_analytics_workspace.monitoring.primary_shared_key}\n    log_type FluentBitLogs\n"
        filters = "[FILTER]\n    Name kubernetes\n    Match kube.*\n    Merge_Log On\n    Keep_Log Off\n    K8S-Logging.Parser On\n    K8S-Logging.Exclude On\n"
      }
    })
  ]

  depends_on = [kubernetes_namespace.monitoring]
}

# Create Azure Monitor Workbook
resource "azurerm_application_insights_workbook" "bookstore_workbook" {
  name                = "bookstore-workbook"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  display_name        = "Bookstore API Monitoring"
  data_json = jsonencode({
    version = "Notebook/1.0"
    items = [
      {
        type = 1
        content = {
          json = "# Bookstore API Monitoring Dashboard\n\nThis workbook provides comprehensive monitoring for the Bookstore API running on AKS."
        }
      },
      {
        type = 3
        content = {
          version = "KqlItem/1.0"
          query = "requests\n| where timestamp > ago(1h)\n| summarize count() by bin(timestamp, 5m)\n| render timechart"
          size = 0
          title = "Request Rate (Last Hour)"
          queryType = 0
          resourceType = "microsoft.insights/components"
        }
      },
      {
        type = 3
        content = {
          version = "KqlItem/1.0"
          query = "requests\n| where timestamp > ago(1h)\n| summarize avg(duration) by bin(timestamp, 5m)\n| render timechart"
          size = 0
          title = "Average Response Time (Last Hour)"
          queryType = 0
          resourceType = "microsoft.insights/components"
        }
      },
      {
        type = 3
        content = {
          version = "KqlItem/1.0"
          query = "requests\n| where timestamp > ago(1h) and resultCode startswith \"5\"\n| summarize count() by bin(timestamp, 5m)\n| render timechart"
          size = 0
          title = "Error Rate (Last Hour)"
          queryType = 0
          resourceType = "microsoft.insights/components"
        }
      }
    ]
  })

  tags = {
    Environment = var.environment
    Project     = "bookstore-monitoring"
  }
}

# Create Action Group for alerts
resource "azurerm_monitor_action_group" "bookstore_alerts" {
  name                = "${var.cluster_name}-bookstore-alerts"
  resource_group_name = data.azurerm_resource_group.main.name
  short_name          = "bookstore"

  email_receiver {
    name          = "admin"
    email_address = var.notification_email
  }

  webhook_receiver {
    name        = "slack"
    service_uri = var.slack_webhook_url
  }

  tags = {
    Environment = var.environment
    Project     = "bookstore-monitoring"
  }
}

# Create metric alerts
resource "azurerm_monitor_metric_alert" "high_cpu_usage" {
  name                = "${var.cluster_name}-high-cpu-usage"
  resource_group_name = data.azurerm_resource_group.main.name
  scopes              = [data.azurerm_kubernetes_cluster.aks.id]
  description         = "Alert when CPU usage is high"
  severity            = 2
  frequency           = "PT1M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "Microsoft.ContainerService/managedClusters"
    metric_name      = "node_cpu_usage_percentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = azurerm_monitor_action_group.bookstore_alerts.id
  }

  tags = {
    Environment = var.environment
    Project     = "bookstore-monitoring"
  }
}

resource "azurerm_monitor_metric_alert" "high_memory_usage" {
  name                = "${var.cluster_name}-high-memory-usage"
  resource_group_name = data.azurerm_resource_group.main.name
  scopes              = [data.azurerm_kubernetes_cluster.aks.id]
  description         = "Alert when memory usage is high"
  severity            = 2
  frequency           = "PT1M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "Microsoft.ContainerService/managedClusters"
    metric_name      = "node_memory_working_set_percentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = azurerm_monitor_action_group.bookstore_alerts.id
  }

  tags = {
    Environment = var.environment
    Project     = "bookstore-monitoring"
  }
}

# Create Application Insights alert for high error rate
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "high_error_rate" {
  name                = "${var.cluster_name}-high-error-rate"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  
  evaluation_frequency = "PT5M"
  window_duration      = "PT10M"
  scopes               = [azurerm_application_insights.monitoring.id]
  severity             = 2
  
  criteria {
    query                   = <<-QUERY
      requests
      | where timestamp > ago(10m)
      | where resultCode startswith "5"
      | summarize ErrorCount = count() by bin(timestamp, 5m)
      | where ErrorCount > 10
    QUERY
    time_aggregation_method = "Count"
    threshold               = 0
    operator                = "GreaterThan"

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  action {
    action_groups = [azurerm_monitor_action_group.bookstore_alerts.id]
  }

  tags = {
    Environment = var.environment
    Project     = "bookstore-monitoring"
  }
}

# Create availability test
resource "azurerm_application_insights_web_test" "bookstore_availability" {
  name                    = "${var.cluster_name}-availability-test"
  location                = data.azurerm_resource_group.main.location
  resource_group_name     = data.azurerm_resource_group.main.name
  application_insights_id = azurerm_application_insights.monitoring.id
  kind                    = "ping"
  frequency               = 300
  timeout                 = 30
  enabled                 = true
  geo_locations           = ["us-tx-sn1-azr", "us-il-ch1-azr", "us-ca-sjc-azr"]

  configuration = <<XML
<WebTest Name="BookstoreAvailabilityTest" Id="ABD48585-0831-40CB-9069-682EA6BB3583" Enabled="True" CssProjectStructure="" CssIteration="" Timeout="30" WorkItemIds="" xmlns="http://microsoft.com/schemas/VisualStudio/TeamTest/2010" Description="" CredentialUserName="" CredentialPassword="" PreAuthenticate="True" Proxy="default" StopOnError="False" RecordedResultFile="" ResultsLocale="">
  <Items>
    <Request Method="GET" Guid="a5f10126-e4cd-570d-961c-cea43999a200" Version="1.1" Url="https://api.${var.domain_name}/health" ThinkTime="0" Timeout="30" ParseDependentRequests="True" FollowRedirects="True" RecordResult="True" Cache="False" ResponseTimeGoal="0" Encoding="utf-8" ExpectedHttpStatusCode="200" ExpectedResponseUrl="" ReportingName="" IgnoreHttpStatusCode="False" />
  </Items>
</WebTest>
XML

  tags = {
    Environment = var.environment
    Project     = "bookstore-monitoring"
  }
}

# Get current Azure client configuration
data "azurerm_client_config" "current" {}