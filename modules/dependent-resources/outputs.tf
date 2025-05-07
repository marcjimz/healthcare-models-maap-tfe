// ─── Unique suffix ─────────────────────────────────────────────────────────────
output "suffix" {
  description = "Random suffix for uniqueness"
  value       = random_string.suffix.result
}

// ─── Core RG info ───────────────────────────────────────────────────────────────
output "resource_group_name" {
  description = "Name of the core resource group"
  value       = data.azurerm_resource_group.rg.name
}

output "location" {
  description = "Location of the core resource group"
  value       = data.azurerm_resource_group.rg.location
}

// ─── Networking ─────────────────────────────────────────────────────────────────
output "vnet_id" {
  description = "ID of the core virtual network"
  value       = azurerm_virtual_network.core_vnet.id
}

output "subnet_id" {
  description = "ID of the core subnet"
  value       = azurerm_subnet.core_subnet.id
}

// ─── AI Foundry dependencies ────────────────────────────────────────────────────
output "storage_account_id" {
  description = "ID of the storage account"
  value       = azurerm_storage_account.sa.id
}

output "key_vault_id" {
  description = "ID of the key vault"
  value       = azapi_resource.kv.id
}

output "container_registry_id" {
  description = "ID of the container registry"
  value       = azurerm_container_registry.acr.id
}

// ─── (Optional) Cognitive Services ──────────────────────────────────────────────
output "ai_services_id" {
  description = "ID of the Cognitive Services account (if you plan to hook it up)"
  value       = azurerm_cognitive_account.cogs.id
}