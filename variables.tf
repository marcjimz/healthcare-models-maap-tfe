variable "subscription_id" {
  type        = string
  description = "Your Azure Subscription ID"
}

variable "resource_group_location" {
  type        = string
  default     = "eastus"
  description = "Azure region for all resources."
}

variable "aihubname" {
  type        = string
  description = "Base name for all AI Foundry resources."
}