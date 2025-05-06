variable "subscription_id" {
  type        = string
  description = "Your Azure Subscription ID"
}

variable "resource_group_location" {
  type        = string
  default     = "eastus2"
  description = "Azure region for all resources."
}

variable "aihubname" {
  type        = string
  description = "Base name for all AI Foundry resources."
}

variable "vm_name" {
  type = string
  default = "windows-bastion"
}

variable "admin_username" {
  type = string
  default = "azureuser"
}

variable "admin_password" {
  type      = string
  sensitive = true
}