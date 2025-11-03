terraform {
  backend "azurerm" {
    resource_group_name  = "rg-aks-microservice"
    storage_account_name = "terraformsatfstate"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }

  required_version = ">= 1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}
