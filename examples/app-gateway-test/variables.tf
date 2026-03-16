variable "gateways" {
  description = "Map of Application Gateways to deploy. The map key can be any logical name."
  type = map(object({
    name                                = string
    resource_group_name                 = string
    location                            = optional(string, "eastus")
    app_gateway_subnet_id               = string
    public_ip_name                      = string
    backend_ip_addresses                = list(string)
    host_names                          = optional(list(string), ["app.contoso.com"])
    ssl_certificate_key_vault_secret_id = optional(string)
    log_analytics_workspace_id          = optional(string)
    tags = optional(map(string), {
      environment = "dev"
      workload    = "network-ingress"
      managedBy   = "terraform"
    })
  }))
}
