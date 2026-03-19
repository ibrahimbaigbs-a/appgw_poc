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

  # Production-grade guardrails: require explicit object graph in JSON and validate references.
  gateways_missing_explicit_graph = [
    for k, v in local.gateways : k
    if(
      length(try(v.frontend_ports, {})) == 0 ||
      length(try(v.backend_address_pools, {})) == 0 ||
      length(try(v.backend_http_settings, {})) == 0 ||
      length(try(v.http_listeners, {})) == 0 ||
      length(try(v.request_routing_rules, {})) == 0
    )
  ]

  gateways_with_unknown_listener_frontend_port = [
    for k, v in local.gateways : k
    if length([
      for lk, lv in try(v.http_listeners, {}) : lk
      if !contains([for pk, pv in try(v.frontend_ports, {}) : pv.name], try(lv.frontend_port_name, ""))
    ]) > 0
  ]

  gateways_with_unknown_listener_frontend_ip = [
    for k, v in local.gateways : k
    if length([
      for lk, lv in try(v.http_listeners, {}) : lk
      if !contains(
        length(try(v.frontend_ip_configurations, {})) > 0 ? [for fk, fv in try(v.frontend_ip_configurations, {}) : fv.name] : ["${v.name}-feip"],
        try(lv.frontend_ip_configuration_name, "")
      )
    ]) > 0
  ]

  gateways_with_unknown_rule_listener = [
    for k, v in local.gateways : k
    if length([
      for rk, rv in try(v.request_routing_rules, {}) : rk
      if !contains([for lk, lv in try(v.http_listeners, {}) : lv.name], try(rv.http_listener_name, ""))
    ]) > 0
  ]

  gateways_with_invalid_https_cert_mapping = [
    for k, v in local.gateways : k
    if length([
      for lk, lv in try(v.http_listeners, {}) : lk
      if lower(try(lv.protocol, "")) == "https" && !contains(
        length(try(v.ssl_certificates, {})) > 0 ? [for ck, cv in try(v.ssl_certificates, {}) : cv.name] : (
          try(v.ssl_certificate_key_vault_secret_id, null) != null ? [try(v.ssl_certificate_name, "web-cert")] : []
        ),
        try(lv.ssl_certificate_name, "")
      )
    ]) > 0
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

    precondition {
      condition     = length(local.gateways_missing_explicit_graph) == 0
      error_message = "Production strict mode is enabled. Missing required explicit JSON blocks for: ${join(", ", local.gateways_missing_explicit_graph)}. Required: frontend_ports, backend_address_pools, backend_http_settings, http_listeners, request_routing_rules."
    }

    precondition {
      condition     = length(local.gateways_with_unknown_listener_frontend_port) == 0
      error_message = "Invalid listener references for gateway(s): ${join(", ", local.gateways_with_unknown_listener_frontend_port)}. Each http_listener.frontend_port_name must match a frontend_ports[*].name value."
    }

    precondition {
      condition     = length(local.gateways_with_unknown_listener_frontend_ip) == 0
      error_message = "Invalid listener references for gateway(s): ${join(", ", local.gateways_with_unknown_listener_frontend_ip)}. Each http_listener.frontend_ip_configuration_name must match a frontend_ip_configurations[*].name value."
    }

    precondition {
      condition     = length(local.gateways_with_unknown_rule_listener) == 0
      error_message = "Invalid routing rule references for gateway(s): ${join(", ", local.gateways_with_unknown_rule_listener)}. Each request_routing_rule.http_listener_name must match an http_listeners[*].name value."
    }

    precondition {
      condition     = length(local.gateways_with_invalid_https_cert_mapping) == 0
      error_message = "Invalid HTTPS certificate mapping for gateway(s): ${join(", ", local.gateways_with_invalid_https_cert_mapping)}. Every Https listener must set ssl_certificate_name that exists in ssl_certificates[*].name (or legacy ssl_certificate_name when ssl_certificate_key_vault_secret_id is used)."
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

  frontend_ip_configurations = try(each.value.frontend_ip_configurations, null)

  frontend_ports = try(each.value.frontend_ports, {})

  backend_address_pools = try(each.value.backend_address_pools, {})

  probes = try(each.value.probes, null)

  backend_http_settings = try(each.value.backend_http_settings, {})

  http_listeners = try(each.value.http_listeners, {})

  request_routing_rules = try(each.value.request_routing_rules, {})

  ssl_certificates = length(try(each.value.ssl_certificates, {})) > 0 ? each.value.ssl_certificates : (
    try(each.value.ssl_certificate_key_vault_secret_id, null) != null ? {
      cert = {
        name                = try(each.value.ssl_certificate_name, "web-cert")
        key_vault_secret_id = each.value.ssl_certificate_key_vault_secret_id
      }
    } : null
  )

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

  managed_identities = try(each.value.managed_identities, null)
}
