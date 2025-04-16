module "dependent_resources" {
  source                     = "./modules/dependent-resources"
  subscription_id            = var.subscription_id
  location                   = var.resource_group_location
  aihubname                  = var.aihubname
}

resource "azurerm_ai_foundry" "hub" {
  name                = "${var.aihubname}-hub-${module.dependent_resources.suffix}"
  location            = module.dependent_resources.ai_services_location
  resource_group_name = module.dependent_resources.resource_group_name
  storage_account_id  = module.dependent_resources.storage_account_id
  key_vault_id        = module.dependent_resources.key_vault_id

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_ai_foundry_project" "project" {
  name               = "proj-${module.dependent_resources.suffix}"
  location           = azurerm_ai_foundry.hub.location
  ai_services_hub_id = azurerm_ai_foundry.hub.id

  identity {
    type = "SystemAssigned"
  }
}