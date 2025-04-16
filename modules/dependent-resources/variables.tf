variable "subscription_id" {
  type        = string
  description = "Your Azure Subscription ID"
}

variable "location" {
  type        = string
  description = "Region for RG, KV, Storage, AI Services"
}

variable "aihubname" {
  type        = string
  description = "Base name for all AI Foundry resources"
}