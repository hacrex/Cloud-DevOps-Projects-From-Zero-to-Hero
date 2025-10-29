terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Enable required APIs
resource "google_project_service" "container_api" {
  service = "container.googleapis.com"
}

resource "google_project_service" "containerregistry_api" {
  service = "containerregistry.googleapis.com"
}

resource "google_project_service" "run_api" {
  service = "run.googleapis.com"
}

# Create Artifact Registry repository
resource "google_artifact_registry_repository" "bookstore_repo" {
  location      = var.region
  repository_id = "bookstore-api"
  description   = "Bookstore API container repository"
  format        = "DOCKER"

  labels = {
    environment = var.environment
  }
}

# Build and push container image using Cloud Build
resource "google_cloudbuild_trigger" "bookstore_build" {
  name        = "bookstore-api-build"
  description = "Build and push bookstore API container"

  github {
    owner = var.github_owner
    name  = var.github_repo
    push {
      branch = "^main$"
    }
  }

  build {
    step {
      name = "gcr.io/cloud-builders/docker"
      args = [
        "build",
        "-t",
        "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.bookstore_repo.repository_id}/bookstore-api:$COMMIT_SHA",
        "."
      ]
    }

    step {
      name = "gcr.io/cloud-builders/docker"
      args = [
        "push",
        "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.bookstore_repo.repository_id}/bookstore-api:$COMMIT_SHA"
      ]
    }

    options {
      logging = "CLOUD_LOGGING_ONLY"
    }
  }
}

# Deploy to Cloud Run
resource "google_cloud_run_service" "bookstore_api" {
  name     = "bookstore-api"
  location = var.region

  template {
    spec {
      containers {
        image = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.bookstore_repo.repository_id}/bookstore-api:latest"
        
        ports {
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
            cpu    = "1000m"
            memory = "512Mi"
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

        startup_probe {
          http_get {
            path = "/health"
            port = 3000
          }
          initial_delay_seconds = 10
          period_seconds        = 5
          failure_threshold     = 30
        }
      }

      container_concurrency = 100
      timeout_seconds       = 300
    }

    metadata {
      annotations = {
        "autoscaling.knative.dev/minScale" = "1"
        "autoscaling.knative.dev/maxScale" = "10"
        "run.googleapis.com/cpu-throttling" = "false"
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  depends_on = [google_project_service.run_api]
}

# Make Cloud Run service publicly accessible
resource "google_cloud_run_service_iam_member" "public_access" {
  service  = google_cloud_run_service.bookstore_api.name
  location = google_cloud_run_service.bookstore_api.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Create Global Load Balancer for custom domain
resource "google_compute_global_address" "api_ip" {
  name = "bookstore-api-ip"
}

# Create SSL certificate
resource "google_compute_managed_ssl_certificate" "api_ssl" {
  name = "bookstore-api-ssl"

  managed {
    domains = ["api.${var.domain_name}"]
  }
}

# Create backend service for Cloud Run
resource "google_compute_region_network_endpoint_group" "api_neg" {
  name                  = "bookstore-api-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.region

  cloud_run {
    service = google_cloud_run_service.bookstore_api.name
  }
}

resource "google_compute_backend_service" "api_backend" {
  name        = "bookstore-api-backend"
  protocol    = "HTTP"
  port_name   = "http"
  timeout_sec = 30

  backend {
    group = google_compute_region_network_endpoint_group.api_neg.id
  }

  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

# Create URL map
resource "google_compute_url_map" "api_url_map" {
  name            = "bookstore-api-url-map"
  default_service = google_compute_backend_service.api_backend.id

  host_rule {
    hosts        = ["api.${var.domain_name}"]
    path_matcher = "allpaths"
  }

  path_matcher {
    name            = "allpaths"
    default_service = google_compute_backend_service.api_backend.id
  }
}

# Create HTTPS proxy
resource "google_compute_target_https_proxy" "api_https_proxy" {
  name             = "bookstore-api-https-proxy"
  url_map          = google_compute_url_map.api_url_map.id
  ssl_certificates = [google_compute_managed_ssl_certificate.api_ssl.id]
}

# Create forwarding rule
resource "google_compute_global_forwarding_rule" "api_https" {
  name       = "bookstore-api-https"
  target     = google_compute_target_https_proxy.api_https_proxy.id
  port_range = "443"
  ip_address = google_compute_global_address.api_ip.address
}

# Create Cloud Monitoring alert policies
resource "google_monitoring_alert_policy" "high_error_rate" {
  display_name = "High Error Rate - Bookstore API"
  combiner     = "OR"

  conditions {
    display_name = "Error rate too high"

    condition_threshold {
      filter          = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"${google_cloud_run_service.bookstore_api.name}\""
      duration        = "300s"
      comparison      = "COMPARISON_GREATER_THAN"
      threshold_value = 0.1

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

# Create notification channel
resource "google_monitoring_notification_channel" "email" {
  display_name = "Email Notification"
  type         = "email"

  labels = {
    email_address = var.notification_email
  }
}

# Create Cloud Logging sink
resource "google_logging_project_sink" "api_logs" {
  name        = "bookstore-api-logs"
  destination = "storage.googleapis.com/${google_storage_bucket.logs_bucket.name}"
  filter      = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"${google_cloud_run_service.bookstore_api.name}\""

  unique_writer_identity = true
}

# Create storage bucket for logs
resource "google_storage_bucket" "logs_bucket" {
  name          = "${var.project_id}-bookstore-logs"
  location      = var.region
  force_destroy = true

  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }
}

# Grant logging sink permission to write to bucket
resource "google_storage_bucket_iam_member" "logs_writer" {
  bucket = google_storage_bucket.logs_bucket.name
  role   = "roles/storage.objectCreator"
  member = google_logging_project_sink.api_logs.writer_identity
}