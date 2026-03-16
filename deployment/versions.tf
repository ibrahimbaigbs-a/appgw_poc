terraform {
  required_version = ">= 1.9, < 2.0"

  # Backend config is supplied at init time via -backend-config flags.
  # State key pattern: <Environment>/<Region>/terraform.tfstate
  # All gateway instances in a region share one state file; Terraform's
  # for_each tracks each primary/secondary resource independently within it.
  backend "azurerm" {}

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.117, < 5.0"
    }
  }
}
