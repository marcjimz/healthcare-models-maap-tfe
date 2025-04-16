resource "random_string" "suffix" {
  length  = 8
  lower   = true
  upper   = false
  numeric = false
  special = false
}

locals {
  full_rg_name = "${var.aihubname}-rg-${random_string.suffix.result}"
  rg_name      = substr(local.full_rg_name, 0, 90)
}

resource "azurerm_resource_group" "rg" {
  name     = local.rg_name
  location = var.location
}

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "kv" {
  name                = "kv-${random_string.suffix.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"
  purge_protection_enabled = true
}

resource "azurerm_key_vault_access_policy" "policy" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  key_permissions = [
    "Create", "Get", "Delete", "Purge", "GetRotationPolicy",
  ]
}

# storage account names must be 3–24 lowercase alphanumeric, no hyphens
locals {
  sa_name = substr(
    replace("sa${random_string.suffix.result}", "-", ""),
    0,
    24
  )
}

resource "azurerm_storage_account" "sa" {
  name                     = local.sa_name
  location                 = azurerm_resource_group.rg.location
  resource_group_name      = azurerm_resource_group.rg.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_ai_services" "ais" {
  name                = "ais-${random_string.suffix.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "S0"
}