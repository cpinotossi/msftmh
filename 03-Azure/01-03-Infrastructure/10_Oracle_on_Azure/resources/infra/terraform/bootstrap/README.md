# GitHub Bootstrap (Terraform)

This folder contains Terraform configuration to bootstrap GitHub Actions automation for this project.

Scope:

- Create baseline Azure resources for automation (resource group, Log Analytics, Container Apps environment, optional Container Apps job, optional Key Vault).
- Create an OIDC federated identity credential on an existing Entra ID app registration (service principal app).

Out of scope:

- No workflow deployment to GitHub.
- No Terraform execution in this bootstrap.
- No workload deployment.

## What this bootstrap prepares

- GitHub OIDC federation for your existing service principal application.
- Optional Azure Container Apps job foundation for running orchestration steps.
- Optional Key Vault to store OCI CLI secrets.

## Usage

1. Copy `terraform.tfvars.example` to `terraform.tfvars`.
2. Fill all required values.
3. Validate only (optional):
   - `terraform init`
   - `terraform validate`

## Notes

- The federated identity subject is built from repo, branch, and optional environment.
- This bootstrap keeps all runtime scripts in your main repository and only provisions control-plane prerequisites.
