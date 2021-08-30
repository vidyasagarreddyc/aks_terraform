# Logic of program is to first generate the Logics corresponding to the resource needs to be created"
# Single variable "iaas" is defined on root lavel, we will generate the locals for the network program.

locals {
  networks = {
      for k,v in try(var.infra.networks, {}) : k => merge(
          {
              resource_group_name = try(var.infra.networks.resource_group_name, local.default_resource_group.name)
              location  = try(var.infra.networks.location, local.default_resource_group.location )
              lookup = false
              nat_gateway_required = false
              subnets = {}
              dns_servers = {}
              is_default = false
          },
          v
      )
  }
}

resource "azurerm_virtual_network" "networks" {
    for_each = {
        for k,v in local.networks : k => v if ! v.lookup
    }
    name = each.key
    address_space = each.value.address_space
    resource_group_name = each.value.resource_group_name
    location = each.value.location
}

data "azurerm_virtual_network" "networks" {
  for_each = local.networks
  name = each.key
  resource_group_name = each.value.resource_group_name
  depends_on = [
    azurerm_virtual_network.networks
  ]
}

locals {
  subnets = {
      for entry in flatten([
          for network_k, network_v in local.networks: [
              for subnet_k, subnet_v in network_v.subnets : merge(
                  {
                      network = network_k
                      subnet = subnet_k
                      lookup = false
                      enforce_private_link_endpoint_network_policies = false
                      enforce_private_link_service_network_policies  = false
                  },
                  subnet_v,
                  {
                      resource_group_name = azurerm_virtual_network.networks[network_k].resource_group_name
                      virtual_network_name = azurerm_virtual_network.networks[network_k].name
                  }
              )
          ]
      ]) : "${entry.network}-${entry.subnet}" => entry
  }
}


resource "azurerm_subnet" "networks" {
  for_each = {
        for k,v in local.subnets : k => v if ! v.lookup
    }
  name = each.value.subnet
  address_prefixes = each.value.address_prefixes
  virtual_network_name = each.value.virtual_network_name
  resource_group_name = data.azurerm_resource_group.resource_group[each.value.resource_group_name].name
}

data "azurerm_subnet" "networks" {
  for_each = local.subnets
  name = each.value.subnet
  virtual_network_name = each.value.virtual_network_name
  resource_group_name = each.value.resource_group_name
  depends_on = [
    azurerm_subnet.networks
  ]
}


# resource "azurerm_kubernetes_cluster" "k8s" {
#   for_each = local.k8s
#   name = each.key
#   res
# }