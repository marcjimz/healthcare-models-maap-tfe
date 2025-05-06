variable "resource_group_name" {
  type        = string
  description = "RG into which to deploy all dependent resources"
}

variable "vnet_id" {
  type        = string
  description = "ID of the VNet to lock down these services into"
}

variable "subnet_id" {
  type        = string
  description = "ID of the Subnet to lock down these services into"
}