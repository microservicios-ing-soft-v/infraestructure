terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.84.0"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  skip_provider_registration = true
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
}

# Container Registry
resource "azurerm_container_registry" "main" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  sku                 = "Basic"
  admin_enabled       = true
}

# Key Vault
resource "azurerm_key_vault" "main" {
  name                        = var.key_vault_name
  location                    = var.location
  resource_group_name         = azurerm_resource_group.main.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  purge_protection_enabled    = false
  enabled_for_disk_encryption = true
  soft_delete_retention_days  = 7
}

resource "azurerm_key_vault_access_policy" "pipeline_secrets_access" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = [
    "Get",
    "List",
    "Set",
    "Delete",
    "Recover",
    "Backup",
    "Restore"
  ]
}

# Log Analytics workspace for Container Apps (configuración mínima)
resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${var.prefix}-${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"  # Este es el más económico
  retention_in_days   = 30           # Mínimo valor permitido
}

# Random string for uniqueness
resource "random_string" "suffix" {
  length  = 5
  special = false
  upper   = false
}

# Container Apps Environment
resource "azurerm_container_app_environment" "main" {
  name                       = "cae-${var.prefix}-${random_string.suffix.result}"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
}

# Virtual Network for Container Apps (optional but recommended for production)
resource "azurerm_virtual_network" "main" {
  name                = "vnet-${var.prefix}"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_subnet" "container_apps" {
  name                 = "subnet-container-apps"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Redis como Container App en lugar de servicio administrado
resource "azurerm_container_app" "redis" {
  name                         = "redis"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  template {
    container {
      name   = "redis"
      image  = "redis:7.0-alpine"
      cpu    = 0.5
      memory = "1Gi"
      
      command = ["redis-server", "--save", "20", "1", "--loglevel", "warning"]
    }
  }

  ingress {
    external_enabled = false
    target_port      = 6379
    traffic_weight {
      percentage = 100
      latest_revision = true
    }
  }
}

# Container Apps
resource "azurerm_container_app" "zipkin" {
  name                         = "zipkin"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  template {
    container {
      name   = "zipkin"
      image  = "ghcr.io/openzipkin/zipkin-slim:latest"
      cpu    = 0.5
      memory = "1Gi"
      
      env {
        name  = "STORAGE_TYPE"
        value = "mem"
      }
    }
  }

  ingress {
    external_enabled = true
    target_port      = 9411
    traffic_weight {
      percentage = 100
      latest_revision = true
    }
  }
}

resource "azurerm_container_app" "users_api" {
  name                         = "users-api"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  registry {
    server               = azurerm_container_registry.main.login_server
    username             = azurerm_container_registry.main.admin_username
    password_secret_name = "acr-password"
  }

  secret {
    name  = "acr-password"
    value = azurerm_container_registry.main.admin_password
  }

  template {
    container {
      name   = "users-api"
      image  = "${azurerm_container_registry.main.login_server}/users-api:${var.image_tag}"
      cpu    = 0.5
      memory = "1Gi"
      
      env {
        name  = "JWT_SECRET"
        value = "PRFT" # Consider using Key Vault reference for production
      }
      
      env {
        name  = "SERVER_PORT"
        value = "8083"
      }
      
      env {
        name  = "ZIPKIN_URL"
        value = "http://zipkin.${azurerm_container_app_environment.main.default_domain}:9411/"
      }
      
      volume_mounts {
        name = "users-data"
        path = "/app/data"
      }
    }
    
    volume {
      name         = "users-data"
      storage_type = "EmptyDir"
    }
  }

  ingress {
    external_enabled = false
    target_port      = 8083
    traffic_weight {
      percentage = 100
      latest_revision = true
    }
  }
}

resource "azurerm_container_app" "auth_api" {
  name                         = "auth-api"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  registry {
    server               = azurerm_container_registry.main.login_server
    username             = azurerm_container_registry.main.admin_username
    password_secret_name = "acr-password"
  }

  secret {
    name  = "acr-password"
    value = azurerm_container_registry.main.admin_password
  }

  template {
    container {
      name   = "auth-api"
      image  = "${azurerm_container_registry.main.login_server}/auth-api:${var.image_tag}"
      cpu    = 0.5
      memory = "1Gi"
      
      env {
        name  = "JWT_SECRET"
        value = "PRFT" # Consider using Key Vault reference for production
      }
      
      env {
        name  = "AUTH_API_PORT"
        value = "8000"
      }
      
      env {
        name  = "USERS_API_ADDRESS"
        value = "http://users-api.${azurerm_container_app_environment.main.default_domain}:8083"
      }
      
      env {
        name  = "ZIPKIN_URL"
        value = "http://zipkin.${azurerm_container_app_environment.main.default_domain}:9411/api/v2/spans"
      }
    }
  }

  ingress {
    external_enabled = false
    target_port      = 8000
    traffic_weight {
      percentage = 100
      latest_revision = true
    }
  }
}

resource "azurerm_container_app" "todos_api" {
  name                         = "todos-api"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  registry {
    server               = azurerm_container_registry.main.login_server
    username             = azurerm_container_registry.main.admin_username
    password_secret_name = "acr-password"
  }

  secret {
    name  = "acr-password"
    value = azurerm_container_registry.main.admin_password
  }

  template {
    container {
      name   = "todos-api"
      image  = "${azurerm_container_registry.main.login_server}/todos-api:${var.image_tag}"
      cpu    = 0.5
      memory = "1Gi"
      
      env {
        name  = "JWT_SECRET"
        value = "PRFT" # Consider using Key Vault reference for production
      }
      
      env {
        name  = "TODO_API_PORT"
        value = "8082"
      }
      
      env {
        name  = "REDIS_HOST"
        value = "redis.${azurerm_container_app_environment.main.default_domain}"
      }
      
      env {
        name  = "REDIS_PORT"
        value = "6379"
      }
      
      env {
        name  = "ZIPKIN_URL"
        value = "http://zipkin.${azurerm_container_app_environment.main.default_domain}:9411/api/v2/spans"
      }
    }
  }

  ingress {
    external_enabled = false
    target_port      = 8082
    traffic_weight {
      percentage = 100
      latest_revision = true
    }
  }
}

resource "azurerm_container_app" "api_gateway" {
  name                         = "api-gateway"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  registry {
    server               = azurerm_container_registry.main.login_server
    username             = azurerm_container_registry.main.admin_username
    password_secret_name = "acr-password"
  }

  secret {
    name  = "acr-password"
    value = azurerm_container_registry.main.admin_password
  }

  template {
    container {
      name   = "api-gateway"
      image  = "${azurerm_container_registry.main.login_server}/api-gateway:${var.image_tag}"
      cpu    = 0.5
      memory = "1Gi"
      
      env {
        name  = "AUTH_API_ADDRESS"
        value = "http://auth-api.${azurerm_container_app_environment.main.default_domain}:8000"
      }
      
      env {
        name  = "TODOS_API_ADDRESS"
        value = "http://todos-api.${azurerm_container_app_environment.main.default_domain}:8082"
      }
      
      env {
        name  = "ZIPKIN_URL"
        value = "http://zipkin.${azurerm_container_app_environment.main.default_domain}:9411/api/v2/spans"
      }
    }
  }

  ingress {
    external_enabled = true
    target_port      = 8090
    traffic_weight {
      percentage = 100
      latest_revision = true
    }
  }
}

resource "azurerm_container_app" "frontend" {
  name                         = "frontend"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  registry {
    server               = azurerm_container_registry.main.login_server
    username             = azurerm_container_registry.main.admin_username
    password_secret_name = "acr-password"
  }

  secret {
    name  = "acr-password"
    value = azurerm_container_registry.main.admin_password
  }

  template {
    container {
      name   = "frontend"
      image  = "${azurerm_container_registry.main.login_server}/frontend:${var.image_tag}"
      cpu    = 0.5
      memory = "1Gi"
      
      env {
        name  = "AUTH_API_ADDRESS"
        value = "http://api-gateway.${azurerm_container_app_environment.main.default_domain}:8090/auth"
      }
      
      env {
        name  = "TODOS_API_ADDRESS"
        value = "http://api-gateway.${azurerm_container_app_environment.main.default_domain}:8090/todos"
      }
      
      env {
        name  = "ZIPKIN_URL"
        value = "http://zipkin.${azurerm_container_app_environment.main.default_domain}:9411/api/v2/spans"
      }
    }
  }

  ingress {
    external_enabled = true
    target_port      = 8080
    traffic_weight {
      percentage = 100
      latest_revision = true
    }
  }
}

resource "azurerm_container_app" "log_message_processor" {
  name                         = "log-message-processor"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  registry {
    server               = azurerm_container_registry.main.login_server
    username             = azurerm_container_registry.main.admin_username
    password_secret_name = "acr-password"
  }

  secret {
    name  = "acr-password"
    value = azurerm_container_registry.main.admin_password
  }

  template {
    container {
      name   = "log-message-processor"
      image  = "${azurerm_container_registry.main.login_server}/log-message-processor:${var.image_tag}"
      cpu    = 0.25
      memory = "0.5Gi"
      
      env {
        name  = "REDIS_HOST"
        value = "redis.${azurerm_container_app_environment.main.default_domain}"
      }
      
      env {
        name  = "REDIS_PORT"
        value = "6379"
      }
      
      env {
        name  = "REDIS_CHANNEL"
        value = "log_channel"
      }
      
      env {
        name  = "ZIPKIN_URL"
        value = "http://zipkin.${azurerm_container_app_environment.main.default_domain}:9411/api/v2/spans"
      }
    }
  }
}
