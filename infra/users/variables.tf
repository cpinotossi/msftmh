# ===============================================================================
# Variable Definitions - Users Infrastructure
# ===============================================================================

# ===============================================================================
# Azure Authentication
# ===============================================================================

variable "tenant_id" {
  description = "Azure AD tenant ID"
  type        = string
  default     = "8fd3e0b6-0302-4084-a31f-1dfc5bbd03f5"
}

# ===============================================================================
# Subscription Configuration
# ===============================================================================

variable "mh0_subscription_id" {
  description = "Single workshop subscription shared by the hub and all user spokes"
  type        = string
  default     = "aca3d6b0-497a-40cc-bdd0-e8e3ef6d8483"
}

variable "mhodaa_subscription_id" {
  description = "Separate subscription for Oracle resources only"
  type        = string
  default     = "4ce5b5cc-e869-451f-98fc-f50448849ee0"
}

variable "use_msi" {
  description = "Use managed identity in CI; false uses Azure CLI authentication"
  type        = bool
  default     = false
}

# ===============================================================================
# Remote State Backend (for reading shared/ outputs)
# ===============================================================================

variable "tf_state_storage" {
  description = "Storage account name for Terraform remote state"
  type        = string
}

variable "tf_state_container" {
  description = "Blob container name for Terraform remote state"
  type        = string
  default     = "tfstate"
}

variable "tf_state_rg" {
  description = "Resource group for Terraform remote state storage account"
  type        = string
}

variable "tf_state_use_azuread_auth" {
  description = "Use Azure AD auth to access remote state (true in CI and locally)"
  type        = bool
  default     = true
}

# ===============================================================================
# Location
# ===============================================================================

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "francecentral"

  validation {
    condition     = contains(["francecentral", "germanywestcentral"], lower(trimspace(var.location)))
    error_message = "location must be either 'francecentral' or 'germanywestcentral'."
  }
}

# ===============================================================================
# User Count
# ===============================================================================

variable "user_count" {
  description = "Number of workshop users to create (0-25)"
  type        = number
  default     = 7

  validation {
    condition     = var.user_count >= 0 && var.user_count <= 25 && floor(var.user_count) == var.user_count
    error_message = "user_count must be an integer between 0 and 25."
  }
}

# ===============================================================================
# VM Configuration
# ===============================================================================

variable "vm_size" {
  description = "Size of the workshop VMs"
  type        = string
  default     = "Standard_D2s_v5"
}

variable "vm_os_disk_type" {
  description = "OS disk type for VMs (Standard_LRS, StandardSSD_LRS, Premium_LRS)"
  type        = string
  default     = "Standard_LRS"
}

variable "vm_os_disk_size_gb" {
  description = "OS disk size in GB"
  type        = number
  default     = 128
}

variable "admin_username" {
  description = "Admin username for VMs"
  type        = string
  default     = "azureuser"
}

variable "vm_image_version" {
  description = "Version of the VM image to use (null = use Ubuntu default)"
  type        = string
  default     = null
}

# ===============================================================================
# ODAA Configuration
# ===============================================================================

# ===============================================================================
# Entra ID Login Configuration
# ===============================================================================

variable "enable_entra_id_login" {
  description = "Enable Entra ID (Azure AD) login for VMs"
  type        = bool
  default     = true
}

variable "entra_id_admin_login" {
  description = "Grant admin (sudo) access to Entra ID users"
  type        = bool
  default     = false
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
  }
}
