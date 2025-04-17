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
  name               = "healthcare-models"
  location           = azurerm_ai_foundry.hub.location
  ai_services_hub_id = azurerm_ai_foundry.hub.id

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