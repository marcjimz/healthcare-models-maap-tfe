output "suffix" {
  value = random_string.suffix.result
}

output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "ai_services_location" {
  value = azurerm_ai_services.ais.location
}

output "key_vault_id" {
  value = azurerm_key_vault.kv.id
}

output "storage_account_id" {
  value = azurerm_storage_account.sa.id
}

output "ai_services_id" {
  value = azurerm_ai_services.ais.id
}