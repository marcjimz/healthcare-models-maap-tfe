// ─── random suffix for uniqueness ────────────────────────────────────────────────────────
resource "random_string" "suffix" {
  length  = 8
  lower   = true
  upper   = false
  numeric = false
  special = false
}

// ─── prereq Resource Group ───────────────────────────────────────────────────────────────
resource "azurerm_resource_group" "prereq" {
  name     = "${var.aihubname}-prereq-rg-${random_string.suffix.result}"
  location = var.resource_group_location
}

// ─── core Resource Group ─────────────────────────────────────────────────────────────────
resource "azurerm_resource_group" "core" {
  name     = "${var.aihubname}-core-rg-${random_string.suffix.result}"
  location = var.resource_group_location

}

// ─── Prerequisite Module ────────────────────────────────────────────────────────────────
module "prereqs" {
  source              = "./modules/prereqs"

  // point at the prereq RG
  resource_group_name = azurerm_resource_group.prereq.name
  location            = azurerm_resource_group.prereq.location

  // your existing prereq inputs
  vm_name        = var.vm_name
  admin_username = var.admin_username
  admin_password = var.admin_password

  depends_on = [
    azurerm_resource_group.prereq
  ]
}

// ─── Core / Dependent Resources Module ─────────────────────────────────────────────────
module "dependent_resources" {
  source = "./modules/dependent-resources"

  // point at the core RG
  resource_group_name = azurerm_resource_group.core.name

  // wire in network IDs from the prereqs
  vnet_id   = module.prereqs.vnet_id
  subnet_id = module.prereqs.subnet_id

  depends_on = [
    module.prereqs,
    azurerm_resource_group.core
  ]

  providers = {
    azurerm = azurerm
    azapi   = azapi
    random  = random
  }
}

# ─── 1) AI Foundry Hub ────────────────────────────────────────────────────────────
resource "azapi_resource" "hub" {
  type      = "Microsoft.MachineLearningServices/workspaces@2024-10-01-preview"
  name      = var.aihubname
  parent_id = azurerm_resource_group.core.id
  location  = azurerm_resource_group.core.location

  schema_validation_enabled = false #required for the latest API preview

  body = jsonencode({
    kind     = "hub"
    identity = { type = "SystemAssigned" }
    properties = {
      # Display name – reuse your hub name (or swap in a new var)
      friendlyName       = var.aihubname
      # Key Vault + Storage + ACR from your dependent_resources module
      keyVault           = module.dependent_resources.key_vault_id
      storageAccount     = module.dependent_resources.storage_account_id
      containerRegistry  = module.dependent_resources.container_registry_id
      # networking
      provisionNetworkNow  = true
      publicNetworkAccess  = "Disabled"
      managedNetwork       = { isolationMode = "AllowInternetOutBound" }
      sharedPrivateLinkResources = []
    }
  })
}

# ─── 2) Private DNS zones (API + Notebooks) ─────────────────────────────────────
resource "azurerm_private_dns_zone" "api" {
  name                = "privatelink.api.azureml.ms"
  resource_group_name = module.dependent_resources.resource_group_name
}

resource "azurerm_private_dns_zone" "notebooks" {
  name                = "privatelink.notebooks.azure.net"
  resource_group_name = module.dependent_resources.resource_group_name
}

# ─── 3) Link DNS zones into your core VNet ──────────────────────────────────────
resource "azurerm_private_dns_zone_virtual_network_link" "api_link" {
  name                  = "${azurerm_private_dns_zone.api.name}-link"
  resource_group_name   = module.dependent_resources.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.api.name
  virtual_network_id    = module.dependent_resources.vnet_id
  registration_enabled  = false
}

resource "azurerm_private_dns_zone_virtual_network_link" "notebooks_link" {
  name                  = "${azurerm_private_dns_zone.notebooks.name}-link"
  resource_group_name   = module.dependent_resources.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.notebooks.name
  virtual_network_id    = module.dependent_resources.vnet_id
  registration_enabled  = false
}

# ─── 4) Private Endpoint for the Hub ───────────────────────────────────────────
resource "azurerm_private_endpoint" "hub_pe" {
  name                = "${var.aihubname}-hub-pe"
  location            = module.dependent_resources.location
  resource_group_name = module.dependent_resources.resource_group_name
  subnet_id           = module.dependent_resources.subnet_id

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [
      azurerm_private_dns_zone.api.id,
      azurerm_private_dns_zone.notebooks.id,
    ]
  }

  private_service_connection {
    name                           = "${var.aihubname}-psc"
    private_connection_resource_id = azapi_resource.hub.id
    subresource_names              = ["amlworkspace"]
    is_manual_connection           = false
  }

  depends_on = [
    azapi_resource.hub,
    azurerm_private_dns_zone_virtual_network_link.api_link,
    azurerm_private_dns_zone_virtual_network_link.notebooks_link,
  ]
}

resource "azurerm_ai_foundry_project" "project" {
  name               = "healthcare-models"
  location           = azapi_resource.hub.location
  ai_services_hub_id = azapi_resource.hub.id

  identity {
    type = "SystemAssigned"
  }
}

resource "azapi_resource" "mii_endpoint_create" {
  type      = "Microsoft.MachineLearningServices/workspaces/onlineEndpoints@2024-04-01-preview"
  name      = "${var.aihubname}-mii-ep"
  parent_id = azurerm_ai_foundry_project.project.id
  location  = var.resource_group_location

  identity {
    type = "SystemAssigned"
  }

  body = {
    kind       = "online"
    properties = {
      authMode    = "key"
      description = "MedImageInsight endpoint"
    }
  }
}

# 2) create the deployment
resource "azapi_resource" "mii_deployment" {
  type      = "Microsoft.MachineLearningServices/workspaces/onlineEndpoints/deployments@2024-01-01-preview"
  name      = "mii-deploy-v9"
  parent_id = azapi_resource.mii_endpoint_create.id
  location  = var.resource_group_location

  tags = {
    environment = "production"
    model       = "MedImageInsight"
  }

  body = {
    properties = {
      # reference the marketplace model
      model = "azureml://registries/azureml/models/MedImageInsight/versions/9"
      instanceType = "Standard_NC24ads_A100_v4" # GPU-backed instance type
      # choose managed compute type for GPU-backed inference
      endpointComputeType = "Managed"

      # concurrency settings
      requestSettings = {
        maxConcurrentRequestsPerInstance = 1
        maxQueueWait                     = "PT0S"
        requestTimeout                   = "PT60S"
      }

    }

    sku = {
      name     = "Standard_NC24ads_A100_v4"
      capacity = 1
      tier     = "Standard"
    }
  }
}

# 3) patch traffic
resource "azapi_update_resource" "mii_endpoint_traffic" {
  type      = "Microsoft.MachineLearningServices/workspaces/onlineEndpoints@2024-04-01-preview"
  name      = azapi_resource.mii_endpoint_create.name
  parent_id = azurerm_ai_foundry_project.project.id

  depends_on = [azapi_resource.mii_deployment]

  body = {
    properties = {
      traffic = {
        (azapi_resource.mii_deployment.name) = 100
      }
    }
  }
}