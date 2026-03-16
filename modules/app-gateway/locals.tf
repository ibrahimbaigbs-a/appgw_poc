locals {
  frontend_ip_configuration_name = "${var.name}-feip"
  gateway_ip_configuration_name  = "${var.name}-gwipc"
  identity_required              = var.managed_identities.system_assigned || length(var.managed_identities.user_assigned_resource_ids) > 0
  managed_identities = {
    type = (
      var.managed_identities.system_assigned && length(var.managed_identities.user_assigned_resource_ids) > 0 ? "SystemAssigned, UserAssigned" :
      var.managed_identities.system_assigned ? "SystemAssigned" :
      "UserAssigned"
    )
    identity_ids = (
      length(var.managed_identities.user_assigned_resource_ids) > 0 ? var.managed_identities.user_assigned_resource_ids : null
    )
  }
  public_ip_address_configuration = {
    resource_group_name              = coalesce(var.public_ip_address_configuration.resource_group_name, var.resource_group_name)
    location                         = coalesce(var.public_ip_address_configuration.location, var.location)
    public_ip_resource_id            = try(var.public_ip_address_configuration.public_ip_resource_id, null)
    allocation_method                = var.public_ip_address_configuration.allocation_method
    ddos_protection_mode             = var.public_ip_address_configuration.ddos_protection_mode
    ddos_protection_plan_resource_id = var.public_ip_address_configuration.ddos_protection_plan_resource_id
    domain_name_label                = var.public_ip_address_configuration.domain_name_label
    edge_zone                        = var.public_ip_address_configuration.edge_zone
    idle_timeout_in_minutes          = var.public_ip_address_configuration.idle_timeout_in_minutes
    ip_tags                          = var.public_ip_address_configuration.ip_tags
    ip_version                       = var.public_ip_address_configuration.ip_version
    public_ip_prefix_resource_id     = var.public_ip_address_configuration.public_ip_prefix_resource_id
    reverse_fqdn                     = var.public_ip_address_configuration.reverse_fqdn
    sku                              = var.public_ip_address_configuration.sku
    sku_tier                         = var.public_ip_address_configuration.sku_tier
    zones                            = var.public_ip_address_configuration.zones
    tags                             = var.public_ip_address_configuration.tags
  }
  role_definition_resource_substring = "/providers/Microsoft.Authorization/roleDefinitions"
}
