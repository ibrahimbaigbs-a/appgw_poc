output "application_gateway_ids" {
  description = "Resource IDs of all deployed Application Gateways."
  value       = { for name, agw in module.app_gateway : name => agw.application_gateway_id }
}

output "application_gateway_names" {
  description = "Names of all deployed Application Gateways."
  value       = { for name, agw in module.app_gateway : name => agw.application_gateway_name }
}
