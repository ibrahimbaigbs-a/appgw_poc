output "application_gateway_ids" {
  value = { for k, m in module.app_gateway : k => m.application_gateway_id }
}

output "application_gateway_names" {
  value = { for k, m in module.app_gateway : k => m.application_gateway_name }
}

output "public_ip_ids" {
  value = { for k, m in module.app_gateway : k => m.public_ip_id }
}

output "public_ip_addresses" {
  value = { for k, m in module.app_gateway : k => m.new_public_ip_address }
}
