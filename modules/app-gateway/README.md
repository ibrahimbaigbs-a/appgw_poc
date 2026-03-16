# Azure Application Gateway Terraform Module

This Terraform module creates an Azure Application Gateway with comprehensive configuration options, following Azure Verified Module (AVM) standards.

## Overview

Azure Application Gateway is a web traffic load balancer that enables you to manage traffic to your web applications. This module provides a complete implementation with support for:

- Backend pools with FQDN and IP address support
- HTTP/HTTPS listeners with SSL certificate management
- Health probes for backend availability detection
- WAF (Web Application Firewall) integration
- URL path-based routing
- Request/response header rewriting
- SSL policies and profiles
- Autoscaling configuration
- Zone redundancy
- Private link configuration
- Managed identities (System and User Assigned)
- Diagnostic settings
- Role assignments

## Features

- ✅ Supports both Standard and WAF SKUs (v1 and v2)
- ✅ Autoscaling capability
- ✅ Zone redundancy for high availability
- ✅ SSL/TLS termination and end-to-end encryption
- ✅ URL-based routing and redirection
- ✅ Custom health probes
- ✅ Connection draining
- ✅ HTTP header rewriting
- ✅ Integration with Azure Key Vault for certificates
- ✅ WAF protection with OWASP rule sets
- ✅ Azure Private Link support
- ✅ Diagnostic settings for monitoring
- ✅ RBAC role assignments
- ✅ Resource locks
- ✅ Telemetry for AVM compliance

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.9, < 2.0 |
| azapi | ~> 2.4 |
| azurerm | >= 3.117, < 5.0 |
| modtm | ~> 0.3 |
| random | >= 3.5.0 |

## Usage

### Basic Example

```hcl
module "application_gateway" {
  source = "./infrastructure/appgateway"

  name                = "my-app-gateway"
  resource_group_name = "my-rg"
  location            = "eastus"

  # Gateway IP Configuration
  gateway_ip_configuration = {
    name      = "my-gateway-ipconfig"
    subnet_id = azurerm_subnet.appgw.id
  }

  # SKU Configuration
  sku = {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }

  # Backend Pool
  backend_address_pools = {
    "backend-pool-1" = {
      name         = "backend-pool-1"
      ip_addresses = ["10.0.1.4", "10.0.1.5"]
    }
  }

  # Backend HTTP Settings
  backend_http_settings = {
    "http-setting-1" = {
      name                  = "http-setting-1"
      cookie_based_affinity = "Disabled"
      port                  = 80
      protocol              = "Http"
      request_timeout       = 30
    }
  }

  # Frontend Port
  frontend_ports = {
    "frontend-port-80" = {
      name = "frontend-port-80"
      port = 80
    }
  }

  # HTTP Listener
  http_listeners = {
    "listener-1" = {
      name                           = "listener-1"
      frontend_ip_configuration_name = "${var.name}-feip"
      frontend_port_name             = "frontend-port-80"
      protocol                       = "Http"
    }
  }

  # Request Routing Rule
  request_routing_rules = {
    "rule-1" = {
      name                       = "rule-1"
      rule_type                  = "Basic"
      http_listener_name         = "listener-1"
      backend_address_pool_name  = "backend-pool-1"
      backend_http_settings_name = "http-setting-1"
      priority                   = 100
    }
  }

  # Public IP Configuration
  public_ip_address_configuration = {
    public_ip_name = "my-appgw-pip"
  }

  tags = {
    environment = "production"
    project     = "my-project"
  }
}
```

### WAF Enabled Example

```hcl
module "application_gateway_waf" {
  source = "./infrastructure/appgateway"

  name                = "my-waf-app-gateway"
  resource_group_name = "my-rg"
  location            = "eastus"

  # WAF SKU
  sku = {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 2
  }

  # WAF Configuration
  waf_configuration = {
    enabled          = true
    firewall_mode    = "Prevention"
    rule_set_type    = "OWASP"
    rule_set_version = "3.2"
  }

  # Autoscaling
  autoscale_configuration = {
    min_capacity = 2
    max_capacity = 10
  }

  # ... other required configurations
}
```

### HTTPS with SSL Certificate

```hcl
module "application_gateway_https" {
  source = "./infrastructure/appgateway"

  name                = "my-https-app-gateway"
  resource_group_name = "my-rg"
  location            = "eastus"

  # SSL Certificate
  ssl_certificates = {
    "ssl-cert-1" = {
      name     = "ssl-cert-1"
      data     = filebase64("./certificate.pfx")
      password = var.ssl_cert_password
    }
  }

  # HTTPS Listener
  http_listeners = {
    "https-listener" = {
      name                           = "https-listener"
      frontend_ip_configuration_name = "${var.name}-feip"
      frontend_port_name             = "frontend-port-443"
      protocol                       = "Https"
      ssl_certificate_name           = "ssl-cert-1"
    }
  }

  # Frontend Port for HTTPS
  frontend_ports = {
    "frontend-port-443" = {
      name = "frontend-port-443"
      port = 443
    }
  }

  # ... other required configurations
}
```

## Inputs

### Required Inputs

| Name | Description | Type |
|------|-------------|------|
| `backend_address_pools` | Backend address pools configuration | `map(object)` |
| `backend_http_settings` | Backend HTTP settings configuration | `map(object)` |
| `frontend_ports` | Frontend ports configuration | `map(object)` |
| `gateway_ip_configuration` | Gateway IP configuration | `object` |
| `http_listeners` | HTTP/HTTPS listeners configuration | `map(object)` |
| `location` | Azure region location | `string` |
| `name` | Application Gateway name | `string` |
| `request_routing_rules` | Request routing rules configuration | `map(object)` |
| `resource_group_name` | Resource group name | `string` |

### Optional Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `sku` | SKU configuration | `object` | `{name="Standard_v2", tier="Standard_v2", capacity=2}` |
| `autoscale_configuration` | Autoscale configuration | `object` | `null` |
| `waf_configuration` | WAF configuration | `object` | `null` |
| `ssl_certificates` | SSL certificates | `map(object)` | `null` |
| `ssl_policy` | SSL policy | `object` | `null` |
| `probes` | Health probes | `map(object)` | `null` |
| `zones` | Availability zones | `list(string)` | `["1", "2", "3"]` |
| `managed_identities` | Managed identities | `object` | `{}` |
| `enable_telemetry` | Enable telemetry | `bool` | `true` |
| `tags` | Resource tags | `map(string)` | `null` |

For a complete list of inputs, see [variables.tf](./variables.tf).

## Outputs

| Name | Description |
|------|-------------|
| `application_gateway_id` | Application Gateway resource ID |
| `application_gateway_name` | Application Gateway name |
| `backend_address_pools` | Backend address pools information |
| `backend_http_settings` | Backend HTTP settings information |
| `frontend_port` | Frontend ports information |
| `http_listeners` | HTTP listeners information |
| `public_ip_id` | Public IP address ID |
| `new_public_ip_address` | Public IP address (if created) |
| `request_routing_rules` | Request routing rules information |
| `ssl_certificates` | SSL certificates information |
| `waf_configuration` | WAF configuration information |

For a complete list of outputs, see [outputs.tf](./outputs.tf).

## Advanced Configuration

### URL Path-Based Routing

```hcl
url_path_map_configurations = {
  "path-map-1" = {
    name                               = "path-map-1"
    default_backend_address_pool_name  = "default-backend"
    default_backend_http_settings_name = "default-http-settings"

    path_rules = [
      {
        name                       = "images-rule"
        paths                      = ["/images/*"]
        backend_address_pool_name  = "images-backend"
        backend_http_settings_name = "images-http-settings"
      },
      {
        name                       = "video-rule"
        paths                      = ["/video/*"]
        backend_address_pool_name  = "video-backend"
        backend_http_settings_name = "video-http-settings"
      }
    ]
  }
}
```

### Health Probes

```hcl
probes = {
  "health-probe-1" = {
    name                = "health-probe-1"
    protocol            = "Http"
    path                = "/health"
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3
    host                = "www.example.com"

    match = {
      status_code = ["200", "201"]
      body        = "healthy"
    }
  }
}
```

### Rewrite Rules

```hcl
rewrite_rule_set = {
  "rewrite-set-1" = {
    name = "rewrite-set-1"

    rewrite_rules = {
      "rule-1" = {
        name          = "add-custom-header"
        rule_sequence = 100

        request_header_configuration = [
          {
            header_name  = "X-Custom-Header"
            header_value = "CustomValue"
          }
        ]
      }
    }
  }
}
```

## Security Considerations

1. **SSL/TLS**: Always use HTTPS with strong SSL policies
2. **WAF**: Enable WAF in Prevention mode for production workloads
3. **Certificates**: Store certificates in Azure Key Vault
4. **Network**: Deploy in dedicated subnet with appropriate NSG rules
5. **Identity**: Use managed identities for Azure resource access
6. **Monitoring**: Enable diagnostic settings and monitoring

## Best Practices

1. Use autoscaling for dynamic workloads
2. Enable zone redundancy for high availability
3. Configure health probes for backend monitoring
4. Implement connection draining for graceful shutdowns
5. Use URL path-based routing for microservices
6. Enable WAF with appropriate rule sets
7. Monitor metrics and logs regularly
8. Use appropriate SKU based on workload requirements

## Module Structure

```
appgateway/
├── main.tf                 # Main resource definitions
├── variables.tf            # Input variables
├── outputs.tf              # Output values
├── locals.tf               # Local values
├── terraform.tf            # Provider requirements
├── main.telemetry.tf       # Telemetry configuration
└── README.md              # This file
```

## References

- [Azure Application Gateway Documentation](https://docs.microsoft.com/en-us/azure/application-gateway/)
- [Azure Application Gateway Terraform Resource](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/application_gateway)
- [Azure Verified Modules](https://aka.ms/avm)
- [Original AVM Module](https://github.com/Azure/terraform-azurerm-avm-res-network-applicationgateway)

## License

This module is based on the Azure Verified Modules (AVM) framework and follows its licensing.

## Contributing

Contributions are welcome! Please follow the standard pull request process.

## Support

For issues and questions, please create an issue in the repository.

---

**Note**: This module is based on the Azure Verified Module for Application Gateway and follows AVM standards and best practices.