variable "location" {
  description = "The Azure region where resources will be created"
  type        = string
  default     = "East US"
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "acr_name" {
  description = "Name of the Azure Container Registry"
  type        = string
}

variable "key_vault_name" {
  description = "Name of the Azure Key Vault"
  type        = string
}

variable "prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "microservice"
}

variable "image_tag" {
  description = "The tag for container images"
  type        = string
  default     = "latest"
}

variable "containerapps_environment_name" {
  description = "Name of the Azure Container Apps environment"
  type        = string
  default     = "my-containerapps-env"
}
