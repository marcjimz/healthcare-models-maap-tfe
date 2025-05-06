output "vnet_name" {
  description = "The name of the created Virtual Network"
  value       = azurerm_virtual_network.core_vnet.name
}

output "subnet_name" {
  description = "The name of the subnet"
  value       = azurerm_subnet.default.name
}

output "public_ip" {
  description = "The public IP address resource ID"
  value       = azurerm_public_ip.bastion_ip.id
}

output "nic_id" {
  description = "The NIC resource ID"
  value       = azurerm_network_interface.bastion_nic.id
}

output "vm_id" {
  description = "The Windows VM resource ID"
  value       = azurerm_windows_virtual_machine.bastion.id
}

output "vnet_id" {
  description = "The ID of the VNet"
  value       = azurerm_virtual_network.core_vnet.id
}

output "subnet_id" {
  description = "The ID of the subnet"
  value       = azurerm_subnet.default.id
}