provider "azurerm" {
  features {}
}

variable infra {}
module "infra" {
  source     = "../../modules/infra"
  infra      = var.infra
  tags       = local.tags
}
