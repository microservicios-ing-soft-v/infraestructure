output "vm_public_ip" {
  description = "The public IP address of the Linux Virtual Machine."
  value       = azurerm_public_ip.main.ip_address
}

output "acr_login_server" {
  description = "The login server name of the Azure Container Registry."
  value       = azurerm_container_registry.main.login_server
}