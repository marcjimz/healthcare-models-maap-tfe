output "suffix" {
  value = random_string.suffix.result
}

output "ai_services_location" {
  value = azurerm_cognitive_account.cogs.location
}

output "key_vault_id" {
  value = azurerm_key_vault.kv.id
}

output "storage_account_id" {
  value = azurerm_storage_account.sa.id
}

output "ai_services_id" {
  value = azurerm_cognitive_account.cogs.id
}