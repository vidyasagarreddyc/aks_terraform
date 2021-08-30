variable "name" {
  description = "(Required) The name of the Node Pool which should be created within the Kubernetes Cluster. Changing this forces a new resource to be created."
  type        = string
  default     = null
}

variable "node_orchestrator_version" {
  description = "(Optional) Version of Kubernetes used for the Agents. If not specified, the latest recommended version will be used at provisioning time (but won't auto-upgrade)"
  type        = string
  default     = "1.20.7"
}

variable "vm_size" {
  description = "(Required) The SKU which should be used for the Virtual Machines used in this Node Pool. Changing this forces a new resource to be created."
  type        = string
  default     = "Standard_DS2_v2"
}

variable "node_pools" {
  description = "Node Pool creation details"
  type = map(object({
        name                          = string,
        node_orchestrator_version     = string,
        node_pool_name                = string,
        node_pool_size                = string,
        node_os_disk_size_gb          = number,
        node_vnet_subnet_id           = string,
        node_enable_auto_scaling      = bool,
        node_agents_max_count         = string,
        node_agents_min_count         = string,
        node_enable_node_public_ip    = bool,
        node_agents_labels            = map(string),
        node_agents_type              = string,
        tags                          = map(string),
        node_agents_max_pods          = number,
        node_enable_host_encryption   = bool,
        node_pool_mode                = string,
        os_type                       = string,
        node_pool_agents_count        = number,
        node_agents_tags              = map(string)
    }))
}