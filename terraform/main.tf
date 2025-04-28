resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "main" {
  name                = "vnet-demo"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_subnet" "main" {
  name                 = "subnet-demo"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_security_group" "main" {
  name                = "nsg-demo"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "Allow-SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "0.0.0.0/0"
    destination_address_prefix = "*"
  }
}

resource "azurerm_public_ip" "main" {
  name                = "publicip-demo"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "main" {
  name                = "nic-demo"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "ipconfig-demo"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.main.id
  }
}

resource "azurerm_network_interface_security_group_association" "main" {
  network_interface_id      = azurerm_network_interface.main.id
  network_security_group_id = azurerm_network_security_group.main.id
}

resource "azurerm_linux_virtual_machine" "main" {
  name                            = "vm-demo"
  resource_group_name             = azurerm_resource_group.main.name
  location                        = var.location
  size                            = "Standard_D2s_v3"
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.main.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }

}
resource "azurerm_container_registry" "main" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  sku                 = "Basic"
  admin_enabled       = true
}
resource "azurerm_role_assignment" "acr_pull" {
  principal_id   = azurerm_linux_virtual_machine.main.identity[0].principal_id
  role_definition_name = "AcrPull"
  scope          = azurerm_container_registry.main.id
}

resource "azurerm_key_vault" "main" {
   name                = var.key_vault_name
   location            = var.location
   resource_group_name = azurerm_resource_group.main.name
   tenant_id           = data.azurerm_client_config.current.tenant_id
   sku_name            = "standard"
   purge_protection_enabled    = false
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
