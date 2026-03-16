locals {
  selected_role = lower(var.role)

  # Scoped to a single instance pair folder: env/<Env>/Region/<Region>/<instance>/
  # One Terraform run = one resilient pair (primary + secondary).
  # Each pair has its own isolated state file, so parallel runs across pairs are safe.
  instance_path = abspath("${path.module}/${var.env_root_path}/${var.environment}/Region/${var.region}/${var.instance}")

  primary_files   = fileset(local.instance_path, "*-p.json")
  secondary_files = fileset(local.instance_path, "*-s.json")
  selected_files = local.selected_role == "p" ? local.primary_files : (
    local.selected_role == "s" ? local.secondary_files : fileset(local.instance_path, "*-[ps].json")
  )

  # Any JSON file in the folder that is NOT a recognised -p.json or -s.json.
  unexpected_files = toset([
    for f in fileset(local.instance_path, "*.json") : f
    if !can(regex("-[ps]\\.json$", f))
  ])

  gateways = {
    for f in local.selected_files :
    replace(replace(basename(f), ".json", ""), "-", "_") => jsondecode(file("${local.instance_path}/${f}"))
  }

  # AzureRM requires at least one backend_address_pool, backend_http_settings,
  # and request_routing_rule on every Application Gateway.
  invalid_backend_gateways = [
    for k, v in local.gateways : k
    if !(
      length(try(v.backend_ip_addresses, [])) > 0 || (
        length(try(v.backend_address_pools, {})) > 0 &&
        length(try(v.backend_http_settings, {})) > 0 &&
        length(try(v.request_routing_rules, {})) > 0
      )
    )
  ]
}

check "primary_secondary_pairing" {
  assert {
    condition     = local.selected_role != "both" || (length(local.primary_files) > 0 && length(local.secondary_files) > 0)
    error_message = "Instance folder '${var.instance}' must contain both a -p.json (primary) and a -s.json (secondary) file when role=both."
  }
}

check "distinct_resource_groups" {
  assert {
    condition = local.selected_role != "both" || length(distinct(
      [for k, v in local.gateways : v.resource_group_name]
    )) == length(local.gateways)
    error_message = "Primary and secondary gateways must use different resource_group_name values to avoid Azure name conflicts when sharing the same gateway name."
  }
}

# Hard plan-time failure — blocks apply, unlike check{} which only warns.
# Prevents silently-ignored JSON files (e.g. appgw-01-t.json) from giving
# operators a false sense that their config was deployed.
resource "terraform_data" "validate_instance_files" {
  lifecycle {
    precondition {
      condition     = length(local.unexpected_files) == 0
      error_message = "Instance folder '${var.instance}' contains unexpected JSON file(s): ${join(", ", local.unexpected_files)}. Only *-p.json (primary) and *-s.json (secondary) are valid."
    }

    precondition {
      condition     = length(local.invalid_backend_gateways) == 0
      error_message = "Gateway config missing required backend settings for: ${join(", ", local.invalid_backend_gateways)}. Provide either non-empty backend_ip_addresses OR explicit backend_address_pools + backend_http_settings + request_routing_rules in the JSON file."
    }
  }
}

module "app_gateway" {
  for_each = local.gateways

  source = "../modules/app-gateway"

  name                = each.value.name
  resource_group_name = each.value.resource_group_name
  location            = try(each.value.location, "westus2")
  zones               = try(each.value.app_gateway_zones, null)

  gateway_ip_configuration = try(each.value.gateway_ip_configuration, {
    name      = "gwipcfg"
    subnet_id = each.value.app_gateway_subnet_id
  })

  public_ip_address_configuration = try(each.value.public_ip_address_configuration, {
    create_public_ip_enabled = true
    public_ip_name           = try(each.value.public_ip_name, "pip-${each.value.name}")
    allocation_method        = "Static"
    sku                      = "Standard"
    sku_tier                 = "Regional"
    zones                    = try(each.value.public_ip_zones, null)
  })

  frontend_ports = length(try(each.value.frontend_ports, {})) > 0 ? each.value.frontend_ports : {
    http = {
      name = "port-80"
      port = 80
    }
    https = {
      name = "port-443"
      port = 443
    }
  }

  backend_address_pools = length(try(each.value.backend_address_pools, {})) > 0 ? each.value.backend_address_pools : (length(try(each.value.backend_ip_addresses, [])) > 0 ? {
    web_pool = {
      name         = "pool-web"
      ip_addresses = toset(each.value.backend_ip_addresses)
    }
  } : {})

  probes = try(each.value.probes, null)

  backend_http_settings = length(try(each.value.backend_http_settings, {})) > 0 ? each.value.backend_http_settings : (length(try(each.value.backend_ip_addresses, [])) > 0 ? {
    web_http = {
      name                  = "bhs-web-http"
      port                  = 80
      protocol              = "Http"
      cookie_based_affinity = "Disabled"
      request_timeout       = 30
      probe_name            = "probe-web"
    }
  } : {})

  http_listeners = length(try(each.value.http_listeners, {})) > 0 ? each.value.http_listeners : {
    http_listener = {
      name                           = "lst-http"
      frontend_port_name             = "port-80"
      frontend_ip_configuration_name = "${each.value.name}-feip"
      protocol                       = "Http"
      host_names                     = try(each.value.host_names, ["app.contoso.com"])
    }
  }

  request_routing_rules = length(try(each.value.request_routing_rules, {})) > 0 ? each.value.request_routing_rules : (length(try(each.value.backend_ip_addresses, [])) > 0 ? {
    web_rule = {
      name                       = "rr-web"
      rule_type                  = "Basic"
      http_listener_name         = "lst-http"
      backend_address_pool_name  = "pool-web"
      backend_http_settings_name = "bhs-web-http"
      priority                   = 100
    }
  } : {})

  ssl_certificates = try(each.value.ssl_certificate_key_vault_secret_id, null) != null ? {
    cert = {
      name                = "web-cert"
      key_vault_secret_id = each.value.ssl_certificate_key_vault_secret_id
    }
  } : null

  diagnostic_settings = try(each.value.log_analytics_workspace_id, null) != null ? {
    law = {
      name                           = "diag-${each.value.name}"
      workspace_resource_id          = each.value.log_analytics_workspace_id
      log_analytics_destination_type = "Dedicated"
      log_groups                     = ["allLogs"]
      metric_categories              = ["AllMetrics"]
    }
  } : {}

  autoscale_configuration = try(each.value.autoscale_configuration, {
    min_capacity = 1
    max_capacity = 2
  })

  sku = try(each.value.sku, {
    name = "Standard_v2"
    tier = "Standard_v2"
  })

  enable_telemetry = false
  tags = try(each.value.tags, {
    environment = lower(var.environment)
    workload    = "network-ingress"
    managedBy   = "terraform"
  })
}
