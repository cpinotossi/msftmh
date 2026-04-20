# ===============================================================================
# Variable Definitions - Users Infrastructure
# ===============================================================================

# ===============================================================================
# Azure Authentication
# ===============================================================================

variable "tenant_id" {
  description = "Azure AD tenant ID"
  type        = string
}

# ===============================================================================
# Subscription Configuration
# ===============================================================================

variable "vm_subscription_id" {
  description = "Azure subscription ID for Workshop VMs, VNets, DNS (sub-mh0)"
  type        = string
}

variable "odaa_subscription_id" {
  description = "Azure subscription ID for ODAA user RGs, peering (sub-mhodaa)"
  type        = string
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
  default     = 3

  validation {
    condition     = var.user_count >= 0 && var.user_count <= 25
    error_message = "user_count must be between 0 and 25."
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

variable "create_public_ip" {
  description = "Create public IPs for VMs (for direct SSH access)"
  type        = bool
  default     = false
}

variable "enable_bastion" {
  description = "Create Azure Bastion for each user VM VNet"
  type        = bool
  default     = true
}

variable "bastion_sku" {
  description = "Azure Bastion SKU"
  type        = string
  default     = "Basic"

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.bastion_sku)
    error_message = "bastion_sku must be one of: Basic, Standard, Premium."
  }
}

variable "enable_nat_gateway" {
  description = "Create a NAT Gateway per user VM VNet for outbound internet access"
  type        = bool
  default     = false
}

# ===============================================================================
# ODAA Configuration
# ===============================================================================

variable "odaa_dns_zone_name" {
  description = "Private DNS zone name for Oracle ODAA"
  type        = string
  default     = "adb.eu-paris-1.oraclecloud.com"
}

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

variable "user_object_ids" {
  description = "Map of user index to Entra ID user object ID"
  type        = map(string)
  default     = {}
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
