output "website_url" {
  description = "The URL of the website"
  value       = "https://${azurerm_cdn_endpoint.website_endpoint.fqdn}"
}

output "storage_account_name" {
  description = "The name of the storage account"
  value       = azurerm_storage_account.website_storage.name
}

output "cdn_endpoint_url" {
  description = "The CDN endpoint URL"
  value       = "https://${azurerm_cdn_endpoint.website_endpoint.fqdn}"
}

output "primary_web_endpoint" {
  description = "The primary web endpoint"
  value       = azurerm_storage_account.website_storage.primary_web_endpoint
}

output "dns_name_servers" {
  description = "The name servers for the DNS zone"
  value       = azurerm_dns_zone.website_dns.name_servers
}

output "traffic_manager_fqdn" {
  description = "The Traffic Manager FQDN"
  value       = azurerm_traffic_manager_profile.website_tm.fqdn
}