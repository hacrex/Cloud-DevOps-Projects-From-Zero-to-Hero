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
resource "google_project_service" "compute_api" {
  service = "compute.googleapis.com"
}

resource "google_project_service" "storage_api" {
  service = "storage.googleapis.com"
}

resource "google_project_service" "dns_api" {
  service = "dns.googleapis.com"
}

# Create a Cloud Storage bucket for static website hosting
resource "google_storage_bucket" "website_bucket" {
  name          = "${var.project_id}-static-website"
  location      = var.region
  force_destroy = true

  website {
    main_page_suffix = "index.html"
    not_found_page   = "404.html"
  }

  cors {
    origin          = ["*"]
    method          = ["GET", "HEAD"]
    response_header = ["*"]
    max_age_seconds = 3600
  }

  uniform_bucket_level_access = true

  labels = {
    environment = var.environment
    project     = "static-website"
  }
}

# Make the bucket publicly readable
resource "google_storage_bucket_iam_member" "public_read" {
  bucket = google_storage_bucket.website_bucket.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

# Upload website files
resource "google_storage_bucket_object" "index_html" {
  name   = "index.html"
  bucket = google_storage_bucket.website_bucket.name
  source = "../index.html"
  content_type = "text/html"
}

resource "google_storage_bucket_object" "styles_css" {
  name   = "styles.css"
  bucket = google_storage_bucket.website_bucket.name
  source = "../styles.css"
  content_type = "text/css"
}

resource "google_storage_bucket_object" "script_js" {
  name   = "script.js"
  bucket = google_storage_bucket.website_bucket.name
  source = "../script.js"
  content_type = "application/javascript"
}

# Create a global external IP address
resource "google_compute_global_address" "website_ip" {
  name = "website-ip"
}

# Create SSL certificate
resource "google_compute_managed_ssl_certificate" "website_ssl" {
  name = "website-ssl"

  managed {
    domains = [var.domain_name, "www.${var.domain_name}"]
  }
}

# Create a backend bucket
resource "google_compute_backend_bucket" "website_backend" {
  name        = "website-backend"
  bucket_name = google_storage_bucket.website_bucket.name
  enable_cdn  = true

  cdn_policy {
    cache_mode                   = "CACHE_ALL_STATIC"
    default_ttl                  = 3600
    max_ttl                      = 86400
    negative_caching             = true
    serve_while_stale            = 86400
    signed_url_cache_max_age_sec = 7200
  }
}

# Create URL map
resource "google_compute_url_map" "website_url_map" {
  name            = "website-url-map"
  default_service = google_compute_backend_bucket.website_backend.id

  host_rule {
    hosts        = [var.domain_name, "www.${var.domain_name}"]
    path_matcher = "allpaths"
  }

  path_matcher {
    name            = "allpaths"
    default_service = google_compute_backend_bucket.website_backend.id
  }
}

# Create HTTPS proxy
resource "google_compute_target_https_proxy" "website_https_proxy" {
  name             = "website-https-proxy"
  url_map          = google_compute_url_map.website_url_map.id
  ssl_certificates = [google_compute_managed_ssl_certificate.website_ssl.id]
}

# Create HTTP proxy for redirect
resource "google_compute_target_http_proxy" "website_http_proxy" {
  name    = "website-http-proxy"
  url_map = google_compute_url_map.website_url_map.id
}

# Create global forwarding rule for HTTPS
resource "google_compute_global_forwarding_rule" "website_https" {
  name       = "website-https"
  target     = google_compute_target_https_proxy.website_https_proxy.id
  port_range = "443"
  ip_address = google_compute_global_address.website_ip.address
}

# Create global forwarding rule for HTTP
resource "google_compute_global_forwarding_rule" "website_http" {
  name       = "website-http"
  target     = google_compute_target_http_proxy.website_http_proxy.id
  port_range = "80"
  ip_address = google_compute_global_address.website_ip.address
}

# Create Cloud DNS managed zone
resource "google_dns_managed_zone" "website_zone" {
  name        = "website-zone"
  dns_name    = "${var.domain_name}."
  description = "DNS zone for static website"

  labels = {
    environment = var.environment
  }
}

# Create DNS A record
resource "google_dns_record_set" "website_a" {
  name = google_dns_managed_zone.website_zone.dns_name
  type = "A"
  ttl  = 300

  managed_zone = google_dns_managed_zone.website_zone.name

  rrdatas = [google_compute_global_address.website_ip.address]
}

# Create DNS A record for www
resource "google_dns_record_set" "website_www_a" {
  name = "www.${google_dns_managed_zone.website_zone.dns_name}"
  type = "A"
  ttl  = 300

  managed_zone = google_dns_managed_zone.website_zone.name

  rrdatas = [google_compute_global_address.website_ip.address]
}