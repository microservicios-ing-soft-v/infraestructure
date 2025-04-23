variable "resource_group_name" {
  description = "Name for resource group"
  type        = string
}

variable "location" {
  description = "Azure region where resources will be deployed"
  type        = string
  default     = "East US"
}

variable "admin_username" {
  description = "Username for the VM administrator account"
  type        = string
}

variable "admin_password" {
  description = "Password for the VM administrator account"
  type        = string
  sensitive   = true
}

variable "acr_name" {
  description = "Name for the Azure Container Registry"
  type        = string
}

variable "key_vault_name" {
  description = "Name for the Azure Key Vault"
  type        = string
}