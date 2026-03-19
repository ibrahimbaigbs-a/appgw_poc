# Deployment Layer for Application Gateway

This folder is the customer deployment wrapper for the reusable module in `modules/app-gateway`.

## Repository Structure

```
env/
  <Env>/                      ← Prod | NonProd
    Region/
      <Region>/               ← Westus-2 | Eastus-2 | …
        <instance>/           ← logical app gateway pair name
          <instance>-p.json   ← PRIMARY instance config
          <instance>-s.json   ← SECONDARY instance config (resilience)
```

Every `-p.json` and `-s.json` file is an independent Azure Application Gateway.  
Having both files per folder is the intended resilient architecture (active-active pair).  
A folder with only `-p.json` is valid but will produce a Terraform pairing warning until `-s.json` is added.

## Remote State Strategy

**State granularity: one state file per Environment + Region.**

| Scope | State key |
|---|---|
| Prod / Westus-2 | `Prod/Westus-2/terraform.tfstate` |
| Prod / Eastus-2 | `Prod/Eastus-2/terraform.tfstate` |
| NonProd / Westus-2 | `NonProd/Westus-2/terraform.tfstate` |

Within each state file, Terraform tracks every gateway instance as a separate resource entry (e.g. `module.app_gateway["appgw_01_p"]`, `module.app_gateway["appgw_01_s"]`).  
This means adding `appgw-03-s.json` produces a plan that only creates `appgw_03_s` — the existing `appgw-01` and `appgw-02` resources are not touched.

State is stored in Azure Blob Storage. The following GitHub secrets are required:

| Secret | Description |
|---|---|
| `TF_STATE_RESOURCE_GROUP` | Resource group containing the storage account |
| `TF_STATE_STORAGE_ACCOUNT` | Storage account name |
| `AZURE_CLIENT_ID` | OIDC client ID for federated auth |
| `AZURE_TENANT_ID` | Azure tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID |

## Pipeline Change Detection

**On pull request:** the pipeline reads `git diff` to extract which `env/<Env>/Region/<Region>/` paths were touched, deduplicates them into env+region pairs, and runs a parallel plan job for each affected scope.

Example: Adding `env/Prod/Region/Westus-2/appgw-03/appgw-03-s.json` triggers a plan scoped to `Prod / Westus-2`. No other scope is touched.

**On workflow_dispatch:** the operator explicitly picks environment, region, and operation (plan or apply).

## How It Works

1. `detect-scope` job: parses `git diff` → outputs a JSON matrix of `{environment, region}` objects.
2. `validate` job: fmt/init/validate always runs on every PR regardless of scope.
3. `plan` job: runs in parallel for each detected scope, initialising Terraform against the correct remote state blob, then produces a saved plan artifact.
4. `apply` job: manual only — downloads the saved plan artifact and applies it against the same state.

## JSON Contract

Each JSON file (-p or -s) should provide these keys:

- `name` (string)
- `resource_group_name` (string)
- `location` (string, for Azure location, for example `westus2`)
- `app_gateway_subnet_id` (string)
- `public_ip_name` (string)
- `backend_ip_addresses` (array of strings)
- `host_names` (array of strings, optional)
- `ssl_certificate_key_vault_secret_id` (string or null, optional)
- `log_analytics_workspace_id` (string or null, optional)
- `sku` (object, optional)
- `autoscale_configuration` (object, optional)
- `tags` (map, optional)

## Production Mode (Explicit)

This deployment wrapper is explicit-only for production-grade safety. Each gateway JSON must define:

- `frontend_ports`
- `backend_address_pools`
- `backend_http_settings`
- `http_listeners`
- `request_routing_rules`

Plan-time validation enforces reference integrity:

- Every listener `frontend_port_name` must exist in `frontend_ports[*].name`
- Every listener `frontend_ip_configuration_name` must exist in `frontend_ip_configurations[*].name`
- Every routing rule `http_listener_name` must exist in `http_listeners[*].name`
- Every `Https` listener `ssl_certificate_name` must map to an existing certificate name

For production deployments with multiple certificates/listeners, prefer `ssl_certificates` map in JSON and point each `Https` listener to the matching certificate `name`.

## Run Locally

```bash
cd deployment
terraform init
terraform validate
terraform plan
terraform apply
```

To target a different environment path:

```bash
terraform plan -var="environment=Prod" -var="region=Westus-2"
```
