output "vm_public_ip" {
  description = "Public IP address of the VM"
  value       = azurerm_public_ip.main.ip_address
}

output "acr_login_server" {
  description = "URL of the Azure Container Registry"
  value       = azurerm_container_registry.main.login_server
}