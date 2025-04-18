variable "location" {
  description = "Location of the resources in Azure"
  type        = string
  default     = "East US"
}

variable "admin_username" {
  description = "Administrator username for the VM"
  type        = string
  default     = "azureuser"
}

variable "admin_password" {
  description = "Administrator user's password"
  type        = string
  sensitive   = true
  default     = "Password@1234"
}

variable "acr_name" {
  description = "Name of the Azure Container Registry"
  type        = string
  default     = "ingesoftbarrazadylanacr"
}
