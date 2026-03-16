module "app_gateway" {
  for_each = var.gateways

  source = "../../modules/app-gateway"

  name                = each.value.name
  resource_group_name = each.value.resource_group_name
  location            = each.value.location

  gateway_ip_configuration = {
    name      = "gwipcfg"
    subnet_id = each.value.app_gateway_subnet_id
  }

  public_ip_address_configuration = {
    create_public_ip_enabled = true
    public_ip_name           = each.value.public_ip_name
    allocation_method        = "Static"
    sku                      = "Standard"
    sku_tier                 = "Regional"
    zones                    = ["1", "2", "3"]
  }

  frontend_ports = {
    http = {
      name = "port-80"
      port = 80
    }
    https = {
      name = "port-443"
      port = 443
    }
  }

  backend_address_pools = {
    web_pool = {
      name         = "pool-web"
      ip_addresses = toset(each.value.backend_ip_addresses)
    }
  }

  probes = {
    web = {
      name                = "probe-web"
      protocol            = "Http"
      path                = "/health"
      interval            = 30
      timeout             = 30
      unhealthy_threshold = 3
      host                = each.value.backend_ip_addresses[0]
      match = {
        status_code = ["200-399"]
      }
    }
  }

  backend_http_settings = {
    web_http = {
      name                  = "bhs-web-http"
      port                  = 80
      protocol              = "Http"
      cookie_based_affinity = "Disabled"
      request_timeout       = 30
      probe_name            = "probe-web"
    }
  }

  http_listeners = {
    http_listener = {
      name                           = "lst-http"
      frontend_port_name             = "port-80"
      frontend_ip_configuration_name = "${each.value.name}-feip"
      protocol                       = "Http"
      host_names                     = each.value.host_names
    }
  }

  request_routing_rules = {
    web_rule = {
      name                       = "rr-web"
      rule_type                  = "Basic"
      http_listener_name         = "lst-http"
      backend_address_pool_name  = "pool-web"
      backend_http_settings_name = "bhs-web-http"
      priority                   = 100
    }
  }

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

  autoscale_configuration = {
    min_capacity = 1
    max_capacity = 2
  }

  sku = {
    name = "Standard_v2"
    tier = "Standard_v2"
  }

  enable_telemetry = false
  tags             = each.value.tags
}
