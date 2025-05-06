variable "resource_group_name" {
  type        = string
  description = "Name of the resource group into which to deploy the prereqs"
}

variable "location" {
  type        = string
  description = "Azure region (e.g. eastus2)"
}

variable "vm_name" {
  type        = string
  description = "Name of the Windows bastion VM"
}

variable "admin_username" {
  type        = string
  description = "Admin username for the VM"
}

variable "admin_password" {
  type        = string
  description = "Admin password for the VM"
  sensitive   = true
}