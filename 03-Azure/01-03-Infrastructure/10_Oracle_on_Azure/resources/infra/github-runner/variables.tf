# ===============================================================================
# Variables - GitHub Actions Runner on Container Apps
# ===============================================================================

# ===============================================================================
# Azure Authentication
# ===============================================================================

variable "tenant_id" {
  description = "Azure AD tenant ID"
  type        = string
}

variable "client_id" {
  description = "Service Principal client ID (optional, falls back to Azure CLI auth)"
  type        = string
  default     = null
}

variable "client_secret" {
  description = "Service Principal client secret (optional, falls back to Azure CLI auth)"
  type        = string
  sensitive   = true
  default     = null
}

# ===============================================================================
# Subscription Configuration
# ===============================================================================

variable "sub_mhcore_id" {
  description = "Azure subscription ID for sub-mhcore (Compute Gallery, Runner)"
  type        = string
}

variable "sub_mh0_id" {
  description = "Azure subscription ID for sub-mh0 (Workshop VMs, VNets)"
  type        = string
}

variable "sub_mhodaa_id" {
  description = "Azure subscription ID for sub-mhodaa (ODAA VNets, User RGs)"
  type        = string
}

# ===============================================================================
# Location
# ===============================================================================

variable "location" {
  description = "Azure region for the runner infrastructure"
  type        = string
  default     = "francecentral"
}

# ===============================================================================
# GitHub Configuration
# ===============================================================================

variable "github_pat" {
  description = "GitHub Personal Access Token with repo, workflow, admin:org scopes"
  type        = string
  sensitive   = true
}

variable "github_owner" {
  description = "GitHub organization or user name"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name (without owner)"
  type        = string
}

variable "github_runner_scope" {
  description = "Runner scope: 'repo' for repository-level or 'org' for organization-level"
  type        = string
  default     = "repo"

  validation {
    condition     = contains(["repo", "org"], var.github_runner_scope)
    error_message = "github_runner_scope must be 'repo' or 'org'."
  }
}

# ===============================================================================
# Tags
# ===============================================================================

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Project   = "OracleWorkshop"
    ManagedBy = "Terraform"
    Component = "GitHubRunner"
  }
}

# ===============================================================================
# Resource Names (all configurable, use prefix odaamh)
# ===============================================================================

variable "resource_group_name" {
  description = "Name of the resource group for the runner"
  type        = string
  default     = "rg-odaamh-github-runner"
}

variable "managed_identity_name" {
  description = "Name of the managed identity for the runner"
  type        = string
  default     = "id-odaamh-github-runner"
}

variable "key_vault_name" {
  description = "Name of the Key Vault (must be globally unique, max 24 chars)"
  type        = string
  default     = "kv-odaamh-ghrunner"
}

variable "log_analytics_name" {
  description = "Name of the Log Analytics workspace"
  type        = string
  default     = "log-odaamh-github-runner"
}

variable "container_app_env_name" {
  description = "Name of the Container Apps Environment"
  type        = string
  default     = "cae-odaamh-github-runner"
}

variable "container_app_job_name" {
  description = "Name of the Container App Job"
  type        = string
  default     = "caj-odaamh-github-runner"
}

variable "storage_account_name" {
  description = "Name of the storage account for Terraform state (must be globally unique, lowercase, no hyphens)"
  type        = string
  default     = "stodaamhtfstate"
}

variable "storage_container_name" {
  description = "Name of the blob container for Terraform state"
  type        = string
  default     = "tfstate"
}

# ===============================================================================
# VNet Configuration (for Private Endpoint + Container Apps)
# ===============================================================================

variable "vnet_name" {
  description = "Name of the VNet for Container Apps and Private Endpoints"
  type        = string
  default     = "vnet-odaamh-github-runner"
}

variable "vnet_address_space" {
  description = "Address space for the VNet"
  type        = string
  default     = "10.250.0.0/16"
}

variable "subnet_container_apps_name" {
  description = "Name of the subnet for Container Apps"
  type        = string
  default     = "snet-container-apps"
}

variable "subnet_container_apps_prefix" {
  description = "Address prefix for Container Apps subnet (min /23 required)"
  type        = string
  default     = "10.250.0.0/23"
}

variable "subnet_private_endpoints_name" {
  description = "Name of the subnet for Private Endpoints"
  type        = string
  default     = "snet-private-endpoints"
}

variable "subnet_private_endpoints_prefix" {
  description = "Address prefix for Private Endpoints subnet"
  type        = string
  default     = "10.250.2.0/24"
}

variable "storage_private_endpoint_name" {
  description = "Name of the Private Endpoint for the Storage Account"
  type        = string
  default     = "pe-odaamh-storage"
}
