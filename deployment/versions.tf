terraform {
  required_version = ">= 1.9, < 2.0"

  # Backend config is supplied at init time via -backend-config flags.
  # State key pattern: <Environment>/<AppCode>/<Instance>/<Role>/terraform.tfstate
  # Each primary/secondary gateway role has an isolated state file.
  backend "azurerm" {}

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.117, < 5.0"
    }
  }
}
