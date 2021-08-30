locals {
  resource_groups = {
    for v in try(var.infra.resource_groups, {}): v.name => merge(
      {
        lookup     = false
        tags       = try(var.tags, {})
        is_default = false
        },
        v
    )
  }
}

resource "azurerm_resource_group" "resource_group" {
    for_each = {
      for k,v in local.resource_groups : k =>  v if ! v.lookup
    }

    name     = each.key
    location = each.value.location
    tags     = each.value.tags
}

data "azurerm_resource_group" "resource_group" {
  for_each   = local.resource_groups
  name       = each.key
  depends_on = [
    azurerm_resource_group.resource_group
  ]
}

# Now we are implementing the default resource group to implement the resources, for the resource group with the property "is_default" true will be
# considered as the default resource group for the resource creation.

locals {
  default_resource_group = [
    for k,v in local.resource_groups : {
      name     = data.azurerm_resource_group.resource_group[k].name
      location = v.location
    } if v.is_default
  ][0]
}

output "default_rg" {
  value = local.default_resource_group

}