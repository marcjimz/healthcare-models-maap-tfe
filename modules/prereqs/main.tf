# 1) Virtual Network + Subnet
resource "azurerm_virtual_network" "core_vnet" {
  name                = "CoreVnet"
  location            = var.location
  resource_group_name = var.resource_group_name

  address_space = ["10.1.0.0/24"]
}

resource "azurerm_subnet" "default" {
  name                 = "default"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.core_vnet.name

  address_prefixes = ["10.1.0.0/28"]

  service_endpoints = [
    "Microsoft.CognitiveServices",
    "Microsoft.ContainerRegistry",
    "Microsoft.KeyVault",
    "Microsoft.Storage",
  ]
}

# 2) Public IP
resource "azurerm_public_ip" "bastion_ip" {
  name                = "windows-bastion-ip"
  location            = var.location
  resource_group_name = var.resource_group_name

  allocation_method = "Dynamic"
  sku               = "Basic"
}

# 3) Network Interface
resource "azurerm_network_interface" "bastion_nic" {
  name                = "windows-bastion-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.default.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.bastion_ip.id
  }
}

# 4) Windows VM
resource "azurerm_windows_virtual_machine" "bastion" {
  name                = var.vm_name
  location            = var.location
  resource_group_name = var.resource_group_name

  network_interface_ids = [
    azurerm_network_interface.bastion_nic.id
  ]

  size                = "Standard_B2s"
  admin_username      = var.admin_username
  admin_password      = var.admin_password

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
}