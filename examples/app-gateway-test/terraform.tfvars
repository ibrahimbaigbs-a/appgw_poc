gateways = {
  primary = {
    name                  = "agw-dev-eastus-01"
    resource_group_name   = "MigrationRG"
    location              = "eastus"
    app_gateway_subnet_id = "/subscriptions/5ade8a7e-f940-457e-9b4e-65bd6e1d0a29/resourceGroups/migrationrg/providers/Microsoft.Network/virtualNetworks/MigrationRG-vnet/subnets/appgatewaysnet"
    public_ip_name        = "pip-agw-dev-eastus-01"
    backend_ip_addresses  = ["10.0.0.4"]
    host_names            = ["app.contoso.com"]

    ssl_certificate_key_vault_secret_id = null
    log_analytics_workspace_id          = null

    tags = {
      environment = "dev"
      workload    = "network-ingress"
      managedBy   = "terraform"
    }
  }

  secondary = {
    name                  = "agw-dev-eastus-02"
    resource_group_name   = "MigrationRG"
    location              = "eastus"
    app_gateway_subnet_id = "/subscriptions/5ade8a7e-f940-457e-9b4e-65bd6e1d0a29/resourceGroups/migrationrg/providers/Microsoft.Network/virtualNetworks/MigrationRG-vnet/subnets/appgatewaysnet"
    public_ip_name        = "pip-agw-dev-eastus-02"
    backend_ip_addresses  = ["10.0.0.5"]
    host_names            = ["app2.contoso.com"]

    ssl_certificate_key_vault_secret_id = null
    log_analytics_workspace_id          = null

    tags = {
      environment = "dev"
      workload    = "network-ingress"
      managedBy   = "terraform"
    }
  }
}
