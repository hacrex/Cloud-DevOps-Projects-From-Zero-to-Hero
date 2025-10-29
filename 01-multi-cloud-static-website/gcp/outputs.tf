output "website_url" {
  description = "The URL of the website"
  value       = "https://${var.domain_name}"
}

output "bucket_name" {
  description = "The name of the storage bucket"
  value       = google_storage_bucket.website_bucket.name
}

output "load_balancer_ip" {
  description = "The IP address of the load balancer"
  value       = google_compute_global_address.website_ip.address
}

output "dns_name_servers" {
  description = "The name servers for the DNS zone"
  value       = google_dns_managed_zone.website_zone.name_servers
}