resource "random_string" "suffix" {
  length  = 8
  lower   = true
  upper   = false
  numeric = false
  special = false
}

# ─── DATA SOURCES ─────────────────────────────────────────────────────────────────
data "azurerm_client_config" "current" {}

data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

# ─── CORE VNET + SUBNET ────────────────────────────────────────────────────────────
resource "azurerm_virtual_network" "core_vnet" {
  name                = "${data.azurerm_resource_group.rg.name}-core-vnet-${random_string.suffix.result}"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  address_space       = ["10.0.0.0/26"]
}

resource "azurerm_subnet" "core_subnet" {
  name                 = "${data.azurerm_resource_group.rg.name}-core-subnet-${random_string.suffix.result}"
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.core_vnet.name
  address_prefixes     = ["10.0.0.0/26"]

  service_endpoints = [
    "Microsoft.KeyVault",
    "Microsoft.Storage",
    "Microsoft.CognitiveServices",
    "Microsoft.ContainerRegistry",
  ]
}

# ─── LOG ANALYTICS (ARM) ─────────────────────────────────────────────────────────
resource "azapi_resource" "law_arm" {
  type      = "Microsoft.OperationalInsights/workspaces@2022-10-01"
  name      = "loganalytics-${random_string.suffix.result}"
  parent_id = data.azurerm_resource_group.rg.id
  location  = data.azurerm_resource_group.rg.location

  # disable AzAPI’s built-in schema check so we don’t need to duplicate name/location
  schema_validation_enabled = false

  body = jsonencode({
    properties = {
      sku                             = { name = "PerGB2018" }
      retentionInDays                 = 30
      publicNetworkAccessForIngestion = "Enabled"
      publicNetworkAccessForQuery     = "Disabled"
    }
  })
}

resource "azurerm_application_insights" "appi" {
  name                   = "appi-${random_string.suffix.result}"
  location               = data.azurerm_resource_group.rg.location
  resource_group_name    = data.azurerm_resource_group.rg.name
  application_type       = "web"
  retention_in_days      = 30
  workspace_id           = azapi_resource.law_arm.id
}

resource "azapi_resource" "kv" {
  type      = "Microsoft.KeyVault/vaults@2023-07-01"
  name      = "kv-${random_string.suffix.result}"
  parent_id = data.azurerm_resource_group.rg.id
  location  = data.azurerm_resource_group.rg.location

  body = jsonencode({
    properties = {
      createMode                   = "default"
      enabledForDeployment         = false
      enabledForDiskEncryption     = false
      enabledForTemplateDeployment = false
      enableSoftDelete             = true
      enablePurgeProtection        = true
      enableRbacAuthorization      = true
      networkAcls = {
        bypass        = "AzureServices"
        defaultAction = "Deny"
      }
      sku = {
        family = "A"
        name   = "standard"
      }
      softDeleteRetentionInDays = 7
      tenantId                  = data.azurerm_client_config.current.tenant_id
    }
  })
}

resource "azurerm_private_endpoint" "kv_pe" {
  name                = "kv-pe-${random_string.suffix.result}"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "kv-psc"
    private_connection_resource_id = azapi_resource.kv.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }
}

resource "azurerm_private_dns_zone" "kv_dns" {
  name                = "privatelink.vault.azure.net"
  resource_group_name = data.azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "kv_dns_link" {
  name                  = "kv-dnslink"
  resource_group_name   = data.azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.kv_dns.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false
}

resource "azurerm_private_dns_a_record" "kv_dns_a" {
  name                = azapi_resource.kv.name
  zone_name           = azurerm_private_dns_zone.kv_dns.name
  resource_group_name = data.azurerm_resource_group.rg.name
  ttl                 = 300
  records             = [azurerm_private_endpoint.kv_pe.private_service_connection[0].private_ip_address]
}

# ─── STORAGE ACCOUNT ───────────────────────────────────────────────────────────────
resource "azurerm_storage_account" "sa" {
  name                     = substr(replace("sa${random_string.suffix.result}", "-", ""), 0, 24)
  location                 = data.azurerm_resource_group.rg.location
  resource_group_name      = data.azurerm_resource_group.rg.name
  account_tier             = "Standard"
  account_replication_type = "LRS"

  network_rules {
    default_action             = "Deny"
    bypass                     = ["AzureServices"]
    virtual_network_subnet_ids = [azurerm_subnet.core_subnet.id]
  }
}

resource "azurerm_private_endpoint" "sa_blob_pe" {
  name                = "sa-blob-pe-${random_string.suffix.result}"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "sa-blob-psc"
    private_connection_resource_id = azurerm_storage_account.sa.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }
}

resource "azurerm_private_endpoint" "sa_file_pe" {
  name                = "sa-file-pe-${random_string.suffix.result}"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "sa-file-psc"
    private_connection_resource_id = azurerm_storage_account.sa.id
    subresource_names              = ["file"]
    is_manual_connection           = false
  }
}

resource "azurerm_private_dns_zone" "blob_dns" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = data.azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone" "file_dns" {
  name                = "privatelink.file.core.windows.net"
  resource_group_name = data.azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob_dns_link" {
  name                  = "blob-dnslink"
  resource_group_name   = data.azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.blob_dns.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false
}

resource "azurerm_private_dns_zone_virtual_network_link" "file_dns_link" {
  name                  = "file-dnslink"
  resource_group_name   = data.azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.file_dns.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false
}

resource "azurerm_private_dns_a_record" "sa_blob_dns_a" {
  name                = azurerm_storage_account.sa.name
  zone_name           = azurerm_private_dns_zone.blob_dns.name
  resource_group_name = data.azurerm_resource_group.rg.name
  ttl                 = 300
  records             = [azurerm_private_endpoint.sa_blob_pe.private_service_connection[0].private_ip_address]
}

resource "azurerm_private_dns_a_record" "sa_file_dns_a" {
  name                = azurerm_storage_account.sa.name
  zone_name           = azurerm_private_dns_zone.file_dns.name
  resource_group_name = data.azurerm_resource_group.rg.name
  ttl                 = 300
  records             = [azurerm_private_endpoint.sa_file_pe.private_service_connection[0].private_ip_address]
}

# ─── CONTAINER REGISTRY ────────────────────────────────────────────────────────────
resource "azurerm_container_registry" "acr" {
  name                          = "acr${random_string.suffix.result}"
  location                      = data.azurerm_resource_group.rg.location
  resource_group_name           = data.azurerm_resource_group.rg.name
  sku                           = "Premium"
  admin_enabled                 = false

  # turn off the public endpoint entirely
  public_network_access_enabled = false

  # still let trusted Azure services (e.g. your Private Endpoint) in
  network_rule_bypass_option    = "AzureServices"

  network_rule_set {
    default_action = "Deny"
  }
}

resource "azurerm_private_endpoint" "acr_pe" {
  name                = "acr-pe-${random_string.suffix.result}"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "acr-psc"
    private_connection_resource_id = azurerm_container_registry.acr.id
    subresource_names              = ["registry"]
    is_manual_connection           = false
  }
}

resource "azurerm_private_dns_zone" "acr_dns" {
  name                = "privatelink.azurecr.io"
  resource_group_name = data.azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "acr_dns_link" {
  name                  = "acr-dnslink"
  resource_group_name   = data.azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.acr_dns.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false
}

resource "azurerm_private_dns_a_record" "acr_dns_a" {
  name                = azurerm_container_registry.acr.login_server
  zone_name           = azurerm_private_dns_zone.acr_dns.name
  resource_group_name = data.azurerm_resource_group.rg.name
  ttl                 = 300
  records             = [azurerm_private_endpoint.acr_pe.private_service_connection[0].private_ip_address]
}

# ─── COGNITIVE SERVICES ────────────────────────────────────────────────────────────
resource "azurerm_cognitive_account" "cogs" {
  name                          = "cogs-${random_string.suffix.result}"
  location                      = data.azurerm_resource_group.rg.location
  resource_group_name           = data.azurerm_resource_group.rg.name
  kind                          = "CognitiveServices"
  sku_name                      = "S0"
  public_network_access_enabled = false
  custom_subdomain_name         = "ais-${random_string.suffix.result}"

  network_acls {
    default_action = "Deny"

    virtual_network_rules {
      subnet_id                           = azurerm_subnet.core_subnet.id
      ignore_missing_vnet_service_endpoint = true
    }
  }
}

resource "azurerm_private_endpoint" "cogs_pe" {
  name                = "cogs-pe-${random_string.suffix.result}"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "cogs-psc"
    private_connection_resource_id = azurerm_cognitive_account.cogs.id
    subresource_names              = ["account"]
    is_manual_connection           = false
  }
}

resource "azurerm_private_dns_zone" "cog_dns" {
  name                = "privatelink.cognitiveservices.azure.com"
  resource_group_name = data.azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone" "openai_dns" {
  name                = "privatelink.openai.azure.com"
  resource_group_name = data.azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "cog_dns_link" {
  name                  = "cog-dnslink"
  resource_group_name   = data.azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.cog_dns.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false
}

resource "azurerm_private_dns_zone_virtual_network_link" "openai_dns_link" {
  name                  = "openai-dnslink"
  resource_group_name   = data.azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.openai_dns.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false
}

resource "azurerm_private_dns_a_record" "cog_dns_a" {
  name                = azurerm_cognitive_account.cogs.name
  zone_name           = azurerm_private_dns_zone.cog_dns.name
  resource_group_name = data.azurerm_resource_group.rg.name
  ttl                 = 300
  records             = [azurerm_private_endpoint.cogs_pe.private_service_connection[0].private_ip_address]
}

resource "azurerm_private_dns_a_record" "openai_dns_a" {
  name                = azurerm_cognitive_account.cogs.name
  zone_name           = azurerm_private_dns_zone.openai_dns.name
  resource_group_name = data.azurerm_resource_group.rg.name
  ttl                 = 300
  records             = [azurerm_private_endpoint.cogs_pe.private_service_connection[0].private_ip_address]
}

# ─── COGNITIVE SEARCH ─────────────────────────────────────────────────────────────
resource "azurerm_search_service" "search" {
  name                          = "search-${random_string.suffix.result}"
  location                      = data.azurerm_resource_group.rg.location
  resource_group_name           = data.azurerm_resource_group.rg.name
  sku                           = "standard"
  partition_count               = 1
  replica_count                 = 1
  public_network_access_enabled = false
}

resource "azurerm_private_endpoint" "search_pe" {
  name                = "search-pe-${random_string.suffix.result}"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "search-psc"
    private_connection_resource_id = azurerm_search_service.search.id
    subresource_names              = ["searchService"]
    is_manual_connection           = false
  }
}

resource "azurerm_private_dns_zone" "search_dns" {
  name                = "privatelink.search.windows.net"
  resource_group_name = data.azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "search_dns_link" {
  name                  = "search-dnslink"
  resource_group_name   = data.azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.search_dns.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false
}

resource "azurerm_private_dns_a_record" "search_dns_a" {
  name                = azurerm_search_service.search.name
  zone_name           = azurerm_private_dns_zone.search_dns.name
  resource_group_name = data.azurerm_resource_group.rg.name
  ttl                 = 300
  records             = [azurerm_private_endpoint.search_pe.private_service_connection[0].private_ip_address]
}