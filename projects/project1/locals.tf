#-------------------------------
# Local Declarations
#-------------------------------
locals {
  global_configs      = jsondecode(file("../../global_configs.json"))
  project_configs     = jsondecode(file("project_configs.json"))
  prefix              = join("-", [local.project_configs.project_details.project_name,
                                   local.project_configs.project_details.business_unit,
                                   local.project_configs.project_details.team,
                                   local.project_configs.project_details.env,
                                   lookup(local.global_configs.short_region_id, local.project_configs.project_details.location, null)])
  tags                = {
      ProjectName     = local.project_configs.project_details.project_name
      Env             = local.project_configs.project_details.env
      Owner           = local.project_configs.project_details.owner
      BusinessUnit    = local.project_configs.project_details.business_unit
      Team            = local.project_configs.project_details.team
    }
}