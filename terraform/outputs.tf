# Output values
output "acr_login_server" {
  value = azurerm_container_registry.main.login_server
}

output "container_app_environment_default_domain" {
  value = azurerm_container_app_environment.main.default_domain
}

output "frontend_url" {
  value = var.deploy_services && contains(var.deploy_services_list, "frontend") ? try("https://${azurerm_container_app.frontend[0].latest_revision_fqdn}", "No disponible") : "Pendiente de despliegue"
}

output "api_gateway_url" {
  value = var.deploy_services && contains(var.deploy_services_list, "api-gateway") ? try("https://${azurerm_container_app.api_gateway[0].latest_revision_fqdn}", "No disponible") : "Pendiente de despliegue"
}

output "zipkin_url" {
  value = "https://${azurerm_container_app.zipkin.latest_revision_fqdn}"
}

output "redis_host" {
  value = "redis.${azurerm_container_app_environment.main.default_domain}"
}
