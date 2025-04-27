variable "deploy_services" {
  description = "Si se deben desplegar los servicios que dependen de imágenes en ACR"
  type        = bool
  default     = false
}

# Variable para determinar si se despliegan servicios específicos
variable "deploy_services_list" {
  description = "Lista de servicios a desplegar (para despliegues personalizados)"
  type        = set(string)
  default     = ["users-api", "auth-api", "todos-api", "api-gateway", "frontend", "log-message-processor"]
}
