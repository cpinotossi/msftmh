variable "tenant_id" {
  description = "Entra ID tenant ID"
  type        = string
}

variable "bootstrap_subscription_id" {
  description = "Azure subscription ID where bootstrap resources are created"
  type        = string
}

variable "location" {
  description = "Azure region for bootstrap resources"
  type        = string
  default     = "francecentral"
}

variable "name_prefix" {
  description = "Prefix for bootstrap resource names"
  type        = string
  default     = "oraworkshop"
}

variable "github_org" {
  description = "GitHub organization or owner"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}

variable "github_branch" {
  description = "GitHub branch used by workflow dispatch"
  type        = string
  default     = "main"
}

variable "github_environment" {
  description = "Optional GitHub environment name used in OIDC subject (empty = branch subject)"
  type        = string
  default     = ""
}

variable "existing_sp_client_id" {
  description = "Client ID of the existing service principal app registration to federate"
  type        = string
}

variable "create_container_apps_job" {
  description = "Create Azure Container Apps Job baseline"
  type        = bool
  default     = true
}

variable "container_image" {
  description = "Container image for ACA job"
  type        = string
  default     = "mcr.microsoft.com/azure-cli:2.66.0"
}

variable "container_cpu" {
  description = "ACA job container CPU"
  type        = number
  default     = 1.0
}

variable "container_memory" {
  description = "ACA job container memory"
  type        = string
  default     = "2Gi"
}

variable "create_key_vault" {
  description = "Create Key Vault for OCI secrets"
  type        = bool
  default     = true
}

variable "key_vault_name" {
  description = "Name of Key Vault (must be globally unique if create_key_vault=true)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Common tags for bootstrap resources"
  type        = map(string)
  default = {
    Project   = "OracleWorkshop"
    ManagedBy = "Terraform"
    Purpose   = "GitHubBootstrap"
  }
}
