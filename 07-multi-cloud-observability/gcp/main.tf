terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
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

provider "google" {
  project = var.project_id
  region  = var.region
}

# Enable required APIs
resource "google_project_service" "monitoring_api" {
  service = "monitoring.googleapis.com"
}

resource "google_project_service" "logging_api" {
  service = "logging.googleapis.com"
}

resource "google_project_service" "container_api" {
  service = "container.googleapis.com"
}

# Get existing GKE cluster
data "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.region
}

data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://${data.google_container_cluster.primary.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(data.google_container_cluster.primary.master_auth.0.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = "https://${data.google_container_cluster.primary.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(data.google_container_cluster.primary.master_auth.0.cluster_ca_certificate)
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
                storageClassName = "standard-rwo"
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
              job_name = "gcp-monitoring"
              static_configs = [{
                targets = ["monitoring.googleapis.com:443"]
              }]
              metrics_path = "/v1/projects/${var.project_id}/metrics"
              scheme       = "https"
            }
          ]
        }
        service = {
          type = "LoadBalancer"
          annotations = {
            "cloud.google.com/load-balancer-type" = "External"
          }
        }
      }
      grafana = {
        adminPassword = var.grafana_admin_password
        service = {
          type = "LoadBalancer"
          annotations = {
            "cloud.google.com/load-balancer-type" = "External"
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
                name = "Google Cloud Monitoring"
                type = "stackdriver"
                jsonData = {
                  authenticationType = "gce"
                  defaultProject     = var.project_id
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
                storageClassName = "standard-rwo"
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
                  subject = "GKE Alert: {{ .GroupLabels.alertname }}"
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
        outputs = "[OUTPUT]\n    Name stackdriver\n    Match *\n    google_service_credentials /var/secrets/google/key.json\n    export_to_project_id ${var.project_id}\n    resource k8s_container\n    k8s_cluster_name ${var.cluster_name}\n    k8s_cluster_location ${var.region}\n"
        filters = "[FILTER]\n    Name kubernetes\n    Match kube.*\n    Merge_Log On\n    Keep_Log Off\n    K8S-Logging.Parser On\n    K8S-Logging.Exclude On\n"
      }
      serviceAccount = {
        create = true
        annotations = {
          "iam.gke.io/gcp-service-account" = google_service_account.fluent_bit.email
        }
      }
    })
  ]

  depends_on = [kubernetes_namespace.monitoring]
}

# Create service account for Fluent Bit
resource "google_service_account" "fluent_bit" {
  account_id   = "fluent-bit-sa"
  display_name = "Fluent Bit Service Account"
}

# Bind logging write role to Fluent Bit service account
resource "google_project_iam_member" "fluent_bit_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.fluent_bit.email}"
}

# Enable Workload Identity for Fluent Bit
resource "google_service_account_iam_member" "fluent_bit_workload_identity" {
  service_account_id = google_service_account.fluent_bit.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${kubernetes_namespace.monitoring.metadata[0].name}/fluent-bit]"
}

# Create Cloud Monitoring dashboard
resource "google_monitoring_dashboard" "bookstore_dashboard" {
  dashboard_json = jsonencode({
    displayName = "Bookstore API Dashboard"
    mosaicLayout = {
      tiles = [
        {
          width  = 6
          height = 4
          widget = {
            title = "Request Rate"
            xyChart = {
              dataSets = [
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"k8s_container\" AND resource.labels.container_name=\"bookstore-api\""
                      aggregation = {
                        alignmentPeriod  = "60s"
                        perSeriesAligner = "ALIGN_RATE"
                      }
                    }
                  }
                  plotType = "LINE"
                }
              ]
              yAxis = {
                label = "Requests/sec"
              }
            }
          }
        },
        {
          width  = 6
          height = 4
          xPos   = 6
          widget = {
            title = "CPU Usage"
            xyChart = {
              dataSets = [
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"k8s_container\" AND resource.labels.container_name=\"bookstore-api\" AND metric.type=\"kubernetes.io/container/cpu/core_usage_time\""
                      aggregation = {
                        alignmentPeriod  = "60s"
                        perSeriesAligner = "ALIGN_RATE"
                      }
                    }
                  }
                  plotType = "LINE"
                }
              ]
              yAxis = {
                label = "CPU Cores"
              }
            }
          }
        },
        {
          width  = 6
          height = 4
          yPos   = 4
          widget = {
            title = "Memory Usage"
            xyChart = {
              dataSets = [
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"k8s_container\" AND resource.labels.container_name=\"bookstore-api\" AND metric.type=\"kubernetes.io/container/memory/used_bytes\""
                      aggregation = {
                        alignmentPeriod  = "60s"
                        perSeriesAligner = "ALIGN_MEAN"
                      }
                    }
                  }
                  plotType = "LINE"
                }
              ]
              yAxis = {
                label = "Bytes"
              }
            }
          }
        },
        {
          width  = 6
          height = 4
          xPos   = 6
          yPos   = 4
          widget = {
            title = "Pod Count"
            scorecard = {
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"k8s_pod\" AND resource.labels.pod_name=~\"bookstore-api-.*\""
                  aggregation = {
                    alignmentPeriod  = "60s"
                    perSeriesAligner = "ALIGN_MEAN"
                    crossSeriesReducer = "REDUCE_COUNT"
                  }
                }
              }
              sparkChartView = {
                sparkChartType = "SPARK_LINE"
              }
            }
          }
        }
      ]
    }
  })
}

# Create alerting policies
resource "google_monitoring_alert_policy" "high_cpu_usage" {
  display_name = "High CPU Usage - Bookstore API"
  combiner     = "OR"

  conditions {
    display_name = "CPU usage too high"

    condition_threshold {
      filter          = "resource.type=\"k8s_container\" AND resource.labels.container_name=\"bookstore-api\" AND metric.type=\"kubernetes.io/container/cpu/core_usage_time\""
      duration        = "300s"
      comparison      = "COMPARISON_GREATER_THAN"
      threshold_value = 0.8

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.name]

  alert_strategy {
    auto_close = "1800s"
  }
}

resource "google_monitoring_alert_policy" "high_memory_usage" {
  display_name = "High Memory Usage - Bookstore API"
  combiner     = "OR"

  conditions {
    display_name = "Memory usage too high"

    condition_threshold {
      filter          = "resource.type=\"k8s_container\" AND resource.labels.container_name=\"bookstore-api\" AND metric.type=\"kubernetes.io/container/memory/used_bytes\""
      duration        = "300s"
      comparison      = "COMPARISON_GREATER_THAN"
      threshold_value = 400000000 # 400MB

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.name]

  alert_strategy {
    auto_close = "1800s"
  }
}

# Create notification channel
resource "google_monitoring_notification_channel" "email" {
  display_name = "Email Notification"
  type         = "email"

  labels = {
    email_address = var.notification_email
  }
}

# Create log-based metrics
resource "google_logging_metric" "error_rate" {
  name   = "bookstore_error_rate"
  filter = "resource.type=\"k8s_container\" AND resource.labels.container_name=\"bookstore-api\" AND severity>=ERROR"

  metric_descriptor {
    metric_kind = "GAUGE"
    value_type  = "INT64"
    display_name = "Bookstore API Error Rate"
  }

  label_extractors = {
    "pod_name" = "EXTRACT(resource.labels.pod_name)"
  }
}

# Create uptime check
resource "google_monitoring_uptime_check_config" "bookstore_uptime" {
  display_name = "Bookstore API Uptime Check"
  timeout      = "10s"
  period       = "60s"

  http_check {
    path         = "/health"
    port         = 443
    use_ssl      = true
    validate_ssl = true
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = "api.${var.domain_name}"
    }
  }

  content_matchers {
    content = "healthy"
    matcher = "CONTAINS_STRING"
  }
}

# Create SLO
resource "google_monitoring_slo" "bookstore_availability" {
  service      = google_monitoring_service.bookstore_service.service_id
  display_name = "Bookstore API Availability SLO"
  slo_id       = "bookstore-availability-slo"

  goal                = 0.99
  rolling_period_days = 30

  request_based_sli {
    good_total_ratio {
      total_service_filter = "resource.type=\"k8s_container\" AND resource.labels.container_name=\"bookstore-api\""
      good_service_filter  = "resource.type=\"k8s_container\" AND resource.labels.container_name=\"bookstore-api\" AND metric.labels.response_code!~\"5.*\""
    }
  }
}

# Create monitoring service
resource "google_monitoring_service" "bookstore_service" {
  service_id   = "bookstore-api-service"
  display_name = "Bookstore API Service"

  basic_service {
    service_type = "APP_ENGINE"
    service_labels = {
      module_id = "bookstore-api"
    }
  }
}