terraform {
  required_providers {
    azapi = {
      source  = "azure/azapi"
      version = ">= 1.13.1"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.89.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}