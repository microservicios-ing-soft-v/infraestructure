terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "tfstatelsj"
    container_name       = "tfstate"
    key                  = "barraza.dylan.tfstate"
  }
  # Eliminar required_providers (ya está en main.tf)
}
# Eliminar provider "azurerm" y data "azurerm_client_config" (ya están en main.tf)
