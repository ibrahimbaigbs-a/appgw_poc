# App Gateway Module Test Deployment

This folder contains a runnable Terraform test configuration for `../../modules/app-gateway`.
The example supports deploying multiple gateways from a single Terraform run using `for_each`.

## Files

- `versions.tf`: Terraform and provider version constraints
- `providers.tf`: AzureRM provider configuration
- `variables.tf`: Input variables for this test deployment
- `main.tf`: Module invocation using `for_each` over `var.gateways`
- `outputs.tf`: Useful deployment outputs
- `terraform.tfvars.example`: Sample values for multiple gateways

## How To Run

```powershell
cd examples/app-gateway-test
Copy-Item terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your real IDs and values
terraform init
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"
```

## GitHub Actions Pipeline

The repository includes a GitHub Actions workflow at `.github/workflows/app-gateway-test.yml`.

### What It Does

- On pull requests, it runs `terraform fmt -check -recursive`, `terraform init -backend=false`, `terraform validate`, and `tflint --recursive`.
- On manual runs (`workflow_dispatch`), it can execute a real Azure test deployment from this example by running `terraform plan`, optionally `terraform apply`, and optionally `terraform destroy` in the same job.

### Required GitHub Secrets

Configure these repository or environment secrets before using the manual deployment path:

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`
- `TF_VAR_GATEWAYS`

`TF_VAR_GATEWAYS` must be a JSON object matching the `gateways` variable schema. Example secret value:

```json
{
  "primary": {
    "name": "agw-dev-eastus-01",
    "resource_group_name": "MigrationRG",
    "location": "eastus",
    "app_gateway_subnet_id": "/subscriptions/<subscription-id>/resourceGroups/<network-rg>/providers/Microsoft.Network/virtualNetworks/<vnet-name>/subnets/<appgw-subnet-name>",
    "public_ip_name": "pip-agw-dev-eastus-01",
    "backend_ip_addresses": ["10.0.0.4"],
    "host_names": ["app.contoso.com"],
    "ssl_certificate_key_vault_secret_id": null,
    "log_analytics_workspace_id": null,
    "tags": {
      "environment": "dev",
      "workload": "network-ingress",
      "managedBy": "terraform"
    }
  }
}
```

### Azure Authentication Setup

The workflow uses GitHub OIDC through `azure/login@v2`. The Azure application identified by `AZURE_CLIENT_ID` must have federated credentials configured for this repository and enough RBAC permissions to create and delete the Application Gateway, Public IP, and related resources referenced by the example.

### How To Run The Test Deployment

1. Open the `app-gateway-test` workflow in GitHub Actions.
2. Choose `plan` to validate the Azure deployment without creating resources, or choose `apply` to deploy.
3. Leave `destroy_after_apply` set to `true` for ephemeral test runs.

Because the workflow uses the example folder's default local state, `destroy_after_apply=true` is the safest mode for pipeline-based testing.

## Notes

- This test setup uses an HTTP listener and Standard_v2 SKU for a simple first deployment per gateway.
- It expects an existing subnet dedicated to Application Gateway.
- Set `log_analytics_workspace_id` if you want diagnostic settings enabled.
- Set `ssl_certificate_key_vault_secret_id` and extend listeners/rules to HTTPS when needed.
