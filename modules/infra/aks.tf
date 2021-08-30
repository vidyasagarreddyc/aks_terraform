locals {
  aks = {
    for k,v in try(var.infra.aks, {}) : k => merge(
      {
        resource_group_name              = try(v.resource_group_name, local.default_resource_group.name)
        kubernetes_version               = try(var.infra.aks.kubernetes_version, "1.20.7")
        orchestrator_version             = try(var.infra.aks.orchestrator_version, "1.20.7")
        network_plugin                   = try(var.infra.aks.network_plugin, "kubenet")
        vm_size                          = try(var.infra.aks.vm_size, "Standard_D2_v2")
        os_disk_size_gb                  = try(var.infra.aks.os_disk_size_gb, 127)
        sku_tier                         = try(var.infra.aks.sku_tier, "Free")
        dns_prefix                       = null
        api_server_authorized_ip_ranges  = try(var.infra.aks.api_server_authorized_ip_ranges, null)
        enable_role_based_access_control = try(var.infra.aks.enable_role_based_access_control, true)
        # ToDo: Implement dynamically reading information
        rbac_aad_admin_group_object_ids  = "CTE-AKS-ADMINS"
        rbac_aad_managed                 = try(var.infra.aks.rbac_aad_managed, false)
        private_cluster_enabled          = try(var.infra.aks.private_cluster_enabled, true)
        enable_http_application_routing  = try(var.infra.aks.enable_http_application_routing, false)
        enable_azure_policy              = try(var.infra.aks.enable_azure_policy, false)
        network_policy                   = try(var.infra.aks.network_policy, null)
        net_profile_dns_service_ip       = try(var.infra.aks.net_profile_dns_service_ip, null)
        net_profile_docker_bridge_cidr   = try(var.infra.aks.net_profile_docker_bridge_cidr, null)
        net_profile_service_cidr         = try(var.infra.aks.net_profile_service_cidr, null)
        net_profile_pod_cidr             = try(var.infra.aks.net_profile_pod_cidr, null)
        net_profile_outbound_type        = try(var.infra.net_profile_outbound_type, "loadBalancer")
        enable_pod_security_policy       = false
        admin_username                   = try(var.infra.aks.admin_username, "azureuser")
        default_node_pool                = try(var.infra.aks.default_node_pool, {})
        moniroting_enabled               = try(var.infra.aks.moniroting_enabled, true)
        tags                             = var.tags
      },
      v
    )
  }
}

module "ssh-key" {
  source         = "./submodules/ssh-key"
  public_ssh_key = var.public_ssh_key == "" ? "" : var.public_ssh_key
}

resource "azurerm_kubernetes_cluster" "aks" {
  for_each                        = local.aks
  name                            = each.key
  kubernetes_version              = each.value.kubernetes_version
  location                        = data.azurerm_resource_group.resource_group[each.value.resource_group_name].location
  resource_group_name             = data.azurerm_resource_group.resource_group[each.value.resource_group_name].name
  dns_prefix                      = each.value.dns_prefix
  api_server_authorized_ip_ranges = each.value.api_server_authorized_ip_ranges
  sku_tier                        = each.value.sku_tier
  private_cluster_enabled         = each.value.private_cluster_enabled
  enable_pod_security_policy      = each.value.enable_pod_security_policy
  linux_profile {
    admin_username = each.value.admin_username

    ssh_key {
      # remove any new lines using the replace interpolation function
      key_data = replace(var.public_ssh_key == "" ? module.ssh-key.public_ssh_key : var.public_ssh_key, "\n", "")
    }
  }

  default_node_pool {
      name                          = try(each.value.default_node_pool.name, "systempool")
      vm_size                       = try(each.value.default_node_pool.vm_size, "Standard_D2_v2")
      vnet_subnet_id                = data.azurerm_subnet.networks["${each.value.default_node_pool.vnet}-${each.value.default_node_pool.subnet}"].id
      availability_zones            = try(each.value.default_node_pool.availability_zones, [])
      enable_auto_scaling           = try(each.value.default_node_pool.default_node_pool.enable_auto_scaling, false)
      enable_host_encryption        = try(each.value.default_node_pool.default_node_pool.enable_host_encryption, false)
      enable_node_public_ip         = try(each.value.default_node_pool.enable_node_public_ip, false)
      min_count                     = try(each.value.default_node_pool.enable_auto_scaling, false) == true ? try(each.value.default_node_pool.min_count, 1) : null
      max_count                     = try(each.value.default_node_pool.enable_auto_scaling, false) == true ? try(each.value.default_node_pool.max_count, 2) : null
      node_count                    = try(each.value.default_node_pool.enable_auto_scaling, false) == true ? null : try(each.value.default_node_pool.node_count, null)
      max_pods                      = try(each.value.default_node_pool.max_pods, 30)
      node_labels                   = try(each.value.default_node_pool.node_labels, {})
      node_taints                   = try(each.value.default_node_pool.node_taints, [])
      only_critical_addons_enabled  = try(each.value.default_node_pool.only_critical_addons_enabled, false)
      tags                          = try(each.value.default_node_pool.tags, {})
  }


  identity {
    type = "SystemAssigned"
  }

  addon_profile {
    http_application_routing {
      enabled = each.value.enable_http_application_routing
    }


    azure_policy {
      enabled = each.value.enable_azure_policy
    }

    oms_agent {
      enabled = each.value.moniroting_enabled
      log_analytics_workspace_id = each.value.moniroting_enabled == true ? data.azurerm_log_analytics_workspace.log_analytics[each.value.log_analytics_workspace].id : null
    }
  }

  role_based_access_control {
    enabled = each.value.enable_role_based_access_control

    dynamic "azure_active_directory" {
      for_each = each.value.enable_role_based_access_control && each.value.rbac_aad_managed ? ["rbac"] : []
      content {
        managed                = true
        admin_group_object_ids = each.value.rbac_aad_admin_group_object_ids
      }
    }
  }

    # dynamic "azure_active_directory" {
    #   for_each = each.value.enable_role_based_access_control && !each.value.rbac_aad_managed ? ["rbac"] : []
    #   content {
    #     managed           = false
    #     client_app_id     = each.value.rbac_aad_client_app_id
    #     server_app_id     = each.value.rbac_aad_server_app_id
    #     server_app_secret = each.value.rbac_aad_server_app_secret
    #   }
    # }


  network_profile {
    network_plugin     = each.value.network_plugin
    network_policy     = each.value.network_policy
    dns_service_ip     = each.value.net_profile_dns_service_ip
    docker_bridge_cidr = each.value.net_profile_docker_bridge_cidr
    outbound_type      = each.value.net_profile_outbound_type
    pod_cidr           = each.value.net_profile_pod_cidr
    service_cidr       = each.value.net_profile_service_cidr
  }

  tags = each.value.tags
}



# resource "azurerm_kubernetes_cluster_node_pool" "main" {
#   for_each = {
#       for k, v in var.node_pools : k => v
#     }

#     kubernetes_cluster_id  = azurerm_kubernetes_cluster.main.id
#     orchestrator_version   = each.value.node_orchestrator_version
#     name                   = each.value.node_pool_name
#     vm_size                = each.value.node_pool_size
#     os_disk_size_gb        = each.value.node_os_disk_size_gb
#     vnet_subnet_id         = each.value.node_vnet_subnet_id
#     enable_auto_scaling    = each.value.node_enable_auto_scaling
#     node_count             = each.value.node_enable_auto_scaling == true ? null : each.value.node_pool_agents_count
#     max_count              = each.value.node_enable_auto_scaling == true ? each.value.node_agents_max_count : null
#     min_count              = each.value.node_enable_auto_scaling == true ? each.value.node_agents_max_count : null
#     enable_node_public_ip  = each.value.node_enable_node_public_ip
#     node_labels            = each.value.node_agents_labels
#     tags                   = merge(var.tags, each.value.node_agents_tags)
#     max_pods               = each.value.node_agents_max_pods
#     enable_host_encryption = each.value.node_enable_host_encryption
#     mode                   = each.value.node_pool_mode
#     os_type                = each.value.os_type
# }


####### temp need to remove
  # default_node_pool {
  #   orchestrator_version   = each.value.orchestrator_version
  #   name                   = each.value.agents_pool_name
  #   node_count             = each.value.agents_count
  #   vm_size                = each.value.agents_size
  #   os_disk_size_gb        = each.value.os_disk_size_gb
  #   vnet_subnet_id         =  data.azurerm_subnet.networks["${each.value.vnet}-${each.value.subnet}"].id
  #   enable_auto_scaling    = each.value.enable_auto_scaling
  #   max_count              = each.value.agents_min_count
  #   min_count              = each.value.agents_min_count
  #   enable_node_public_ip  = each.value.enable_node_public_ip
  #   availability_zones     = each.value.agents_availability_zones
  #   node_labels            = each.value.agents_labels
  #   type                   = each.value.agents_type
  #   tags                   = each.value.agents_tags
  #   max_pods               = each.value.agents_max_pods
  #   enable_host_encryption = each.value.enable_host_encryption
  # }